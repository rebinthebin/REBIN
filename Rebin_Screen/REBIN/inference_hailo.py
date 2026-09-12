"""
inference_hailo.py
==================
Hailo 8 AI HAT+ (HailoRT) tabanlı yerel model sınıflandırıcısı.
best_rebin.hef modelini Raspberry Pi 5 üzerindeki AI HAT+ donanımında çalıştırır.

Groq API'nin yaptığı her şeyi (ROI kırpma, görüntü ön işleme, sınıflandırma) yerel olarak
ve çok daha düşük gecikmeyle (~5-15 ms) yapar. Supabase, UART ve kiosk bildirimleri
tamamen korunmuştur.
"""

from __future__ import annotations

import os
import sys
import time
import json
import threading
import urllib.request
import numpy as np
import cv2

try:
    from supabase_updater import SupabaseBinUpdater
except ImportError:
    SupabaseBinUpdater = None

# ---------------------------------------------------------------------------
# Hailo Runtime — sadece Raspberry Pi'de mevcut olduğundan güvenli import
# ---------------------------------------------------------------------------
try:
    import hailo_platform as hailo  # type: ignore # hailo-all / hailort paketi
    _HAILO_AVAILABLE = True
except ImportError:
    hailo = None
    _HAILO_AVAILABLE = False

# ---------------------------------------------------------------------------
# Sabitler
# ---------------------------------------------------------------------------
CLASS_NAMES = {0: "glass", 1: "metal", 2: "paper", 3: "plastic"}
# Modelin çıkışı farklı sıralama kullanabilir; .hef inspect ile doğrulanmalı.
# Varsayılan: COCO-benzeri değil, REBIN özel etiket sıralaması ↑

# best_rebin.hef için olası konumlar (önce bulunan kullanılır)
_HEF_SEARCH_PATHS = [
    os.path.join(os.path.dirname(__file__), "..", "best_rebin.hef"),  # proje kökü
    os.path.join(os.path.dirname(__file__), "best_rebin.hef"),        # REBIN/ içinde
    "/home/rebin/Desktop/best_rebin.hef",
    "/home/rebin/Desktop/REBIN/best_rebin.hef",
]


def _find_hef() -> str | None:
    """best_rebin.hef dosyasını bilinen konumlarda arar."""
    for path in _HEF_SEARCH_PATHS:
        resolved = os.path.normpath(path)
        if os.path.isfile(resolved):
            return resolved
    return None


# ---------------------------------------------------------------------------
# HailoClassifier
# ---------------------------------------------------------------------------

class HailoClassifier:
    """
    Hailo 8 AI HAT+ üzerinde best_rebin.hef modelini çalıştıran sınıflandırıcı.

    Giriş: bir veya iki kamera karesi (NumPy RGB uint8 dizisi).
    Çıkış: (material: str, explanation: str) — GroqClassifier ile aynı arayüz.

    Model, YOLOv8 / YOLOv10 end-to-end formatında eğitilmiştir.
    - YOLOv10 e2e çıkışı: (1, 300, 6) → [x1,y1,x2,y2,conf,class_id]
    - YOLOv8 çıkışı: (1, 84, 8400) → transpoze + NMS gerekir
    Kod her iki formatı otomatik algılar.
    """

    def __init__(
        self,
        hef_path: str = None,
        roi_crop_ratios: tuple[float, float, float, float] = None,
        conf_threshold: float = 0.50,
    ):
        self.roi_crop_ratios = roi_crop_ratios
        self.conf_threshold = conf_threshold
        self.is_configured = False
        self._hef_path = hef_path or _find_hef()
        self._network = None      # ConfiguredNetwork nesnesi
        self._input_name: str = ""
        self._output_name: str = ""
        self._input_shape: tuple = (640, 640, 3)
        self._lock = threading.Lock()

        if not _HAILO_AVAILABLE:
            print(
                "Uyarı: 'hailo_platform' paketi bulunamadı. "
                "Hailo 8 AI HAT+ takılı değil veya 'pip install hailo-all' çalıştırılmadı. "
                "Çıkarım devre dışı (UNKNOWN döndürülecek).",
                file=sys.stderr,
            )
            return

        if not self._hef_path:
            print(
                "Uyarı: best_rebin.hef dosyası bulunamadı. "
                "Lütfen dosyanın proje kökünde veya REBIN/ klasöründe olduğunu doğrulayın.",
                file=sys.stderr,
            )
            return

        try:
            self._load_model()
            self.is_configured = True
            print(
                f"Hailo 8 modeli yüklendi: {self._hef_path}  "
                f"| Giriş: {self._input_name} {self._input_shape}",
                file=sys.stderr,
            )
        except Exception as exc:
            print(f"Hata: Hailo modeli yüklenemedi: {exc}", file=sys.stderr)

    # ------------------------------------------------------------------
    # Model yükleme
    # ------------------------------------------------------------------

    def _load_model(self):
        """HEF modelini Hailo cihazına yükler ve I/O stream bilgilerini okur."""
        hef = hailo.HEF(self._hef_path)

        # Hailo cihazını keşfet ve bağlan
        params = hailo.VDevice.create_params()
        self._vdevice = hailo.VDevice(params)

        # Ağ grubu oluştur
        configure_params = hailo.ConfigureParams.create_from_hef(
            hef=hef, interface=hailo.HailoStreamInterface.PCIe
        )
        self._network_groups = self._vdevice.configure(hef, configure_params)
        self._network_group = self._network_groups[0]
        self._network_group_params = self._network_group.create_params()

        # I/O VStream parametrelerini oluştur
        input_vstreams_params = hailo.InputVStreamParams.make(
            self._network_group,
            quantized=False,
            format_type=hailo.FormatType.FLOAT32,
        )
        output_vstreams_params = hailo.OutputVStreamParams.make(
            self._network_group,
            quantized=False,
            format_type=hailo.FormatType.FLOAT32,
        )

        # VStream isimlerini kaydet
        input_vstream_info = hef.get_input_vstream_infos()
        output_vstream_info = hef.get_output_vstream_infos()

        self._input_name = input_vstream_info[0].name
        self._output_name = output_vstream_info[0].name

        # Giriş boyutunu belirle
        shape = input_vstream_info[0].shape  # (H, W, C)
        self._input_shape = tuple(shape)  # örn. (640, 640, 3)

        # VStream param çiftlerini sakla (her classify çağrısında yeniden kullanılacak)
        self._in_params = input_vstreams_params
        self._out_params = output_vstreams_params
        self._hef_obj = hef

    # ------------------------------------------------------------------
    # Görüntü ön işleme
    # ------------------------------------------------------------------

    def _preprocess(self, frame_rgb: np.ndarray) -> np.ndarray:
        """
        RGB kareden Hailo girişi için float32 tensor üretir.
        ROI kırpma + letterbox padding + normalize [0, 1].
        """
        # ROI kırpma
        if self.roi_crop_ratios is not None:
            h, w = frame_rgb.shape[:2]
            y1_r, y2_r, x1_r, x2_r = self.roi_crop_ratios
            y1 = max(0, min(int(y1_r * h), h - 1))
            y2 = max(y1 + 1, min(int(y2_r * h), h))
            x1 = max(0, min(int(x1_r * w), w - 1))
            x2 = max(x1 + 1, min(int(x2_r * w), w))
            frame_rgb = frame_rgb[y1:y2, x1:x2]

        target_h, target_w = self._input_shape[0], self._input_shape[1]
        h, w = frame_rgb.shape[:2]

        # Letterbox: oranı koruyarak yeniden boyutlandır
        scale = min(target_w / w, target_h / h)
        new_w = int(w * scale)
        new_h = int(h * scale)
        resized = cv2.resize(frame_rgb, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

        # Gri dolgu ile hedef boyuta pad et
        padded = np.full((target_h, target_w, 3), 114, dtype=np.uint8)
        dx = (target_w - new_w) // 2
        dy = (target_h - new_h) // 2
        padded[dy : dy + new_h, dx : dx + new_w] = resized

        # float32'ye çevir, normalize et [0, 1]
        tensor = padded.astype(np.float32) / 255.0  # (H, W, 3) NHWC formatı
        return tensor, (scale, dx, dy)

    # ------------------------------------------------------------------
    # Çıkış işleme
    # ------------------------------------------------------------------

    def _postprocess(
        self, raw_output: np.ndarray, scale: float, dx: int, dy: int
    ) -> list[dict]:
        """
        Hailo çıkış tensöründen tespitleri çözer.
        YOLOv10 e2e (1, 300, 6) ve YOLOv8 (1, 84, 8400) formatlarını destekler.
        """
        # Batch boyutunu kaldır
        out = raw_output.squeeze(0)  # (300, 6) veya (84, 8400)

        results = []

        if out.ndim == 2 and out.shape[-1] == 6:
            # YOLOv10 end-to-end formatı: (N, 6) → [x1, y1, x2, y2, conf, class_id]
            for det in out:
                conf = float(det[4])
                if conf < self.conf_threshold:
                    continue
                class_id = int(det[5])
                class_name = CLASS_NAMES.get(class_id, f"unknown_{class_id}")
                x1, y1, x2, y2 = int(det[0]), int(det[1]), int(det[2]), int(det[3])
                # Çok büyük kutular (arka plan hataları) filtrele
                if (x2 - x1) >= 590 and (y2 - y1) >= 390:
                    continue
                results.append({"class_name": class_name, "confidence": conf})

        elif out.ndim == 2 and out.shape[0] == 84:
            # YOLOv8 formatı: (84, 8400) → transpoze → (8400, 84)
            out = out.T  # (8400, 84)
            # İlk 4: cx,cy,w,h — sonraki 80: sınıf skorları (REBIN'de 4 sınıf)
            box_conf = out[:, 4:4 + len(CLASS_NAMES)].max(axis=1)
            class_ids = out[:, 4:4 + len(CLASS_NAMES)].argmax(axis=1)
            mask = box_conf >= self.conf_threshold
            for i in np.where(mask)[0]:
                class_id = int(class_ids[i])
                class_name = CLASS_NAMES.get(class_id, f"unknown_{class_id}")
                results.append(
                    {"class_name": class_name, "confidence": float(box_conf[i])}
                )
        else:
            # Bilinmeyen format — düz max pooling dene
            flat = out.flatten()
            if len(flat) >= len(CLASS_NAMES):
                scores = flat[: len(CLASS_NAMES)]
                best_idx = int(np.argmax(scores))
                best_score = float(scores[best_idx])
                if best_score >= self.conf_threshold:
                    results.append(
                        {
                            "class_name": CLASS_NAMES.get(best_idx, "unknown"),
                            "confidence": best_score,
                        }
                    )

        # Güvene göre azalan sıralama
        results.sort(key=lambda x: x["confidence"], reverse=True)
        return results

    # ------------------------------------------------------------------
    # Ana sınıflandırma fonksiyonu (GroqClassifier.classify ile aynı arayüz)
    # ------------------------------------------------------------------

    def classify(
        self, frame_rgb_0: np.ndarray, frame_rgb_1: np.ndarray = None
    ) -> tuple[str, str]:
        """
        Kamera karelerini işler, Hailo 8 üzerinde çıkarım yapar ve
        (material, explanation) döndürür.

        Tek kamera modunda frame_rgb_1 None olabilir.
        İkili kamera modunda her iki kare birleştirilerek tek bir
        1280×640 görüntü oluşturulur ve 640×640'a küçültülür.
        """
        if not self.is_configured:
            return "unknown", "Hailo modeli yapılandırılmamış (is_configured=False)."

        try:
            # İkili kamera: yanyana birleştir → 640×640
            if frame_rgb_1 is not None:
                def pad640(f):
                    h, w = f.shape[:2]
                    if h == 640 and w == 640:
                        return f
                    padded = np.zeros((640, 640, 3), dtype=np.uint8)
                    padded[(640 - h) // 2:(640 - h) // 2 + h,
                           (640 - w) // 2:(640 - w) // 2 + w] = f
                    return padded

                combined = np.hstack((pad640(frame_rgb_0), pad640(frame_rgb_1)))
                frame_input = cv2.resize(combined, (640, 640), interpolation=cv2.INTER_AREA)
            else:
                frame_input = frame_rgb_0

            # Ön işleme
            tensor, (scale, dx, dy) = self._preprocess(frame_input)
            # Hailo NHWC formatı için batch boyutu ekle: (1, H, W, 3)
            batch = np.expand_dims(tensor, axis=0)

            # Hailo çıkarımı — thread-safe lock ile
            with self._lock:
                with hailo.InferVStreams(
                    self._network_group,
                    self._in_params,
                    self._out_params,
                ) as pipeline:
                    input_data = {self._input_name: batch}
                    pipeline.send(input_data)
                    results_raw = pipeline.recv()

            raw_output = results_raw[self._output_name]  # numpy array

            # Çıkış işleme
            detections = self._postprocess(raw_output, scale, dx, dy)

            if not detections:
                return "unknown", "Tepsi boş veya güven eşiği aşılamadı."

            best = detections[0]
            material = best["class_name"]
            conf_pct = best["confidence"] * 100
            explanation = (
                f"Hailo 8 tespiti: {material.upper()} "
                f"(%{conf_pct:.1f} güven) — {len(detections)} nesne algılandı."
            )
            return material, explanation

        except Exception as exc:
            print(f"Hailo çıkarım hatası: {exc}", file=sys.stderr)
            return "unknown", f"Hailo çıkarım hatası: {exc}"


# ---------------------------------------------------------------------------
# MotionDetector (inference_groq.py'den taşındı — değişmedi)
# ---------------------------------------------------------------------------

class MotionDetector:
    """
    OpenCV arka plan birikimi ve görüntü farkı kullanarak kamera
    akışındaki hareketi algılar.
    """

    def __init__(self, motion_threshold: float = 0.02, still_threshold: float = 0.015):
        self.motion_threshold = motion_threshold
        self.still_threshold = still_threshold
        self.background = None
        self.prev_gray = None
        self.last_bg_ratio = 0.0

    def reset_background(self, frame_rgb: np.ndarray):
        """Referans arka planı ve önceki kareyi mevcut kareye ayarlar."""
        gray = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2GRAY)
        gray = cv2.GaussianBlur(gray, (21, 21), 0)
        self.background = gray.astype("float32")
        self.prev_gray = gray.copy()
        self.last_bg_ratio = 0.0

    def update(self, frame_rgb: np.ndarray, accumulate: bool = True) -> float:
        """
        Mevcut kareyi şunlarla karşılaştırır:
        1. Önceki kare (kareler arası fark: aktif fiziksel hareket)
        2. Referans arka plan (bg farkı: boş tepsiden fark)

        Birincil hareket oranını döndürür (aktif fiziksel hareket).
        """
        gray = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2GRAY)
        gray = cv2.GaussianBlur(gray, (21, 21), 0)

        if self.background is None or self.prev_gray is None:
            self.background = gray.astype("float32")
            self.prev_gray = gray.copy()
            self.last_bg_ratio = 0.0
            return 0.0

        # 1. Kareler arası fark
        frame_diff = cv2.absdiff(self.prev_gray, gray)
        thresh_inter = cv2.threshold(frame_diff, 20, 255, cv2.THRESH_BINARY)[1]
        thresh_inter = cv2.dilate(thresh_inter, None, iterations=2)
        inter_ratio = cv2.countNonZero(thresh_inter) / (
            thresh_inter.shape[0] * thresh_inter.shape[1]
        )
        self.prev_gray = gray.copy()

        # 2. Arka plan farkı
        bg_uint8 = cv2.convertScaleAbs(self.background)
        bg_delta = cv2.absdiff(bg_uint8, gray)
        thresh_bg = cv2.threshold(bg_delta, 25, 255, cv2.THRESH_BINARY)[1]
        thresh_bg = cv2.dilate(thresh_bg, None, iterations=2)
        self.last_bg_ratio = cv2.countNonZero(thresh_bg) / (
            thresh_bg.shape[0] * thresh_bg.shape[1]
        )

        # Boşta kalibrasyon sırasında arka planı yavaşça güncelle
        if accumulate and inter_ratio < self.still_threshold:
            cv2.accumulateWeighted(gray, self.background, 0.02)

        return inter_ratio


# ---------------------------------------------------------------------------
# HailoDetectorController (GroqDetectorController yerine)
# ---------------------------------------------------------------------------

class HailoDetectorController:
    """
    Hareket tetiklemeli Hailo 8 çıkarımı için ana durum makinesi kontrolcüsü.
    GroqDetectorController ile birebir aynı dış arayüze sahiptir.
    """

    def __init__(
        self,
        uart_manager,
        hef_path: str = None,
        motion_threshold: float = 0.02,
        still_threshold: float = 0.015,
        cooldown_time: float = 5.0,
        roi_crop_ratios: tuple[float, float, float, float] = None,
        settle_delay: float = 1.5,
        conf_threshold: float = 0.50,
        on_event=None,
    ):
        self.uart_manager = uart_manager
        self.motion_detector = MotionDetector(motion_threshold, still_threshold)
        self.classifier = HailoClassifier(
            hef_path=hef_path,
            roi_crop_ratios=roi_crop_ratios,
            conf_threshold=conf_threshold,
        )
        self.roi_crop_ratios = roi_crop_ratios
        self.settle_delay = settle_delay
        self.on_event = on_event

        # Supabase bin güncelleyici
        if SupabaseBinUpdater is not None:
            try:
                self.bin_updater = SupabaseBinUpdater()
            except Exception as exc:
                print(f"Uyarı: SupabaseBinUpdater başlatılamadı: {exc}", file=sys.stderr)
                self.bin_updater = None
        else:
            self.bin_updater = None

        self.state = "WAIT_FOR_OBJECT"
        self.still_counter = 0
        self.cooldown_time = cooldown_time
        self.cooldown_start_time = 0.0
        self.placing_start_time = 0.0

        # UI/Durum raporlama alanları
        self.last_material = "None"
        self.last_explanation = ""
        self.last_api_status = "Nesne bekleniyor..."
        self.last_motion_ratio = 0.0

    # ------------------------------------------------------------------
    # Arka plan sıfırlama
    # ------------------------------------------------------------------

    def reset_background(self, frame0: np.ndarray):
        """Hareket dedektörünün arka planını ROI kırpılmış kareyle sıfırlar."""
        if self.roi_crop_ratios is not None:
            h, w = frame0.shape[:2]
            y1_r, y2_r, x1_r, x2_r = self.roi_crop_ratios
            y1 = max(0, min(int(y1_r * h), h - 1))
            y2 = max(y1 + 1, min(int(y2_r * h), h))
            x1 = max(0, min(int(x1_r * w), w - 1))
            x2 = max(x1 + 1, min(int(x2_r * w), w))
            motion_frame = frame0[y1:y2, x1:x2]
        else:
            motion_frame = frame0
        self.motion_detector.reset_background(motion_frame)

    # ------------------------------------------------------------------
    # Kare işleme — durum makinesi
    # ------------------------------------------------------------------

    def process_frame(self, frame0: np.ndarray, frame1: np.ndarray) -> bool:
        """
        Hareket modelini günceller ve durum geçişlerini yönetir.
        Döndürür: API çağrısının hemen tetiklenmesi gerekiyorsa True.
        """
        now = time.time()

        # ROI kırpma ile hareket tespiti (Kamera 0 / RGB üzerinde)
        if self.roi_crop_ratios is not None:
            h, w = frame0.shape[:2]
            y1_r, y2_r, x1_r, x2_r = self.roi_crop_ratios
            y1 = max(0, min(int(y1_r * h), h - 1))
            y2 = max(y1 + 1, min(int(y2_r * h), h))
            x1 = max(0, min(int(x1_r * w), w - 1))
            x2 = max(x1 + 1, min(int(x2_r * w), w))
            motion_frame = frame0[y1:y2, x1:x2]
        else:
            motion_frame = frame0

        accumulate = self.state == "WAIT_FOR_OBJECT"
        motion_ratio = self.motion_detector.update(motion_frame, accumulate=accumulate)
        bg_ratio = self.motion_detector.last_bg_ratio
        self.last_motion_ratio = motion_ratio

        trigger_api = False

        if self.state == "WAIT_FOR_OBJECT":
            if (
                motion_ratio > self.motion_detector.motion_threshold
                or bg_ratio > self.motion_detector.motion_threshold
            ):
                self.state = "OBJECT_PLACING"
                self.placing_start_time = now
                self.last_api_status = "Nesne algılandı. Durulma bekleniyor..."
                self._notify_kiosk_start()
                if self.on_event:
                    self.on_event("MOTION_DETECTED", max(motion_ratio, bg_ratio))

        elif self.state == "OBJECT_PLACING":
            elapsed = now - self.placing_start_time
            remaining = max(0.0, self.settle_delay - elapsed)
            self.last_api_status = f"Durulma sayacı: {remaining:.1f}s kaldı"

            if elapsed >= self.settle_delay:
                if (
                    motion_ratio <= (self.motion_detector.still_threshold * 1.5)
                    or elapsed >= (self.settle_delay + 1.5)
                ):
                    self.state = "REBIN_INFERENCE"
                    self.last_api_status = "Hailo 8 çıkarımı çalıştırılıyor..."
                    if self.on_event:
                        self.on_event("INFERENCE_STARTED", None)
                    trigger_api = True

        elif self.state == "REBIN_INFERENCE":
            pass

        elif self.state == "COOLDOWN":
            current_cooldown = (
                1.0 if self.last_material.lower() == "unknown" else self.cooldown_time
            )
            cooldown_elapsed = now - self.cooldown_start_time
            remaining = max(0.0, current_cooldown - cooldown_elapsed)

            if cooldown_elapsed >= current_cooldown:
                self.last_api_status = "Tepsi temizlenmesi bekleniyor..."
                if motion_ratio < self.motion_detector.still_threshold:
                    self.still_counter += 1
                    if self.still_counter >= 3:
                        self.reset_background(frame0)
                        self.state = "WAIT_FOR_OBJECT"
                        self.last_api_status = "Nesne bekleniyor..."
                        self.last_material = "None"
                        self.last_explanation = ""
                        self._notify_kiosk_ready()
                        if self.on_event:
                            self.on_event("TRAY_CLEARED", None)
                else:
                    self.still_counter = 0
            else:
                self.last_api_status = f"Bekleme: {remaining:.1f}s kaldı"

        return trigger_api

    # ------------------------------------------------------------------
    # Kiosk bildirimleri (değişmedi)
    # ------------------------------------------------------------------

    def _notify_kiosk_start(self):
        """Dokunmatik ekran kiosk'una yükleme animasyonu başlatma bildirimi gönderir."""
        def _post():
            try:
                req = urllib.request.Request(
                    "http://localhost:8080/api/classify/start",
                    data=b"{}",
                    headers={"Content-Type": "application/json"},
                )
                urllib.request.urlopen(req, timeout=0.8)
            except Exception:
                pass
        threading.Thread(target=_post, daemon=True).start()

    def _save_waste_frame(self, frame_rgb: np.ndarray) -> str:
        """Mevcut kamera karesini Ekran'ın waste_images klasörüne kaydeder."""
        try:
            target_dir = "/home/rebin/Desktop/Ekran/data/waste_images"
            os.makedirs(target_dir, exist_ok=True)
            filename = f"waste_{int(time.time() * 1000)}.jpg"
            filepath = os.path.join(target_dir, filename)
            frame_bgr = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)
            cv2.imwrite(filepath, frame_bgr, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
            return filename
        except Exception as exc:
            print(f"Uyarı: Atık karesi kaydedilemedi: {exc}", file=sys.stderr)
            return "sample_plastic_1.png"

    def _notify_kiosk_result(
        self, material: str, confidence: float = 0.96, image_filename: str = ""
    ):
        """Dokunmatik ekran kiosk'una tespit edilen atık türünü ve görüntüyü bildirir."""
        tr_map = {
            "plastic": "Plastik",
            "paper": "Kağıt",
            "glass": "Cam",
            "metal": "Metal",
            "unknown": "Bilinmiyor",
        }
        waste_type = tr_map.get(material.lower(), material.capitalize())
        is_unknown = material.lower() in ("unknown", "none")
        payload = {
            "waste_type": waste_type,
            "confidence": 0.0 if is_unknown else confidence,
            "image_filename": image_filename,
            "cooldown_duration": self.cooldown_time,
            "state": "FAILED" if is_unknown else "COMPLETED",
        }

        def _post():
            try:
                req = urllib.request.Request(
                    "http://localhost:8080/api/classify/result",
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                )
                urllib.request.urlopen(req, timeout=1.0)
            except Exception:
                pass
        threading.Thread(target=_post, daemon=True).start()

    def _notify_kiosk_ready(self):
        """Bekleme süresi bitti ve tepsi temizlendi bildirimi gönderir."""
        def _post():
            try:
                req = urllib.request.Request(
                    "http://localhost:8080/api/system/ready",
                    data=b"{}",
                    headers={"Content-Type": "application/json"},
                )
                urllib.request.urlopen(req, timeout=0.8)
            except Exception:
                pass
        threading.Thread(target=_post, daemon=True).start()

    # ------------------------------------------------------------------
    # Ana sınıflandırma çalıştırıcı
    # ------------------------------------------------------------------

    def run_api_classification(
        self, frame0: np.ndarray, frame1: np.ndarray
    ) -> tuple[str, str, float]:
        """
        Hailo çıkarımını eş zamanlı çalıştırır, seri iletim ve Supabase
        güncellemesini tetikler, ardından bekleme moduna girer.

        Döndürür: (material, explanation, inference_ms)
        """
        t0 = time.perf_counter()
        material, explanation = self.classifier.classify(frame0, frame1)
        t1 = time.perf_counter()

        inference_ms = (t1 - t0) * 1000.0
        self.last_material = material
        self.last_explanation = explanation
        self.last_api_status = f"Sonuç: {material.upper()} ({inference_ms:.0f}ms)"

        if self.on_event:
            self.on_event(
                "CLASSIFICATION_RESULT",
                {
                    "material": material,
                    "explanation": explanation,
                    "latency": inference_ms,
                },
            )

        # Atık görselini kaydet ve kiosk ekranını güncelle
        img_filename = self._save_waste_frame(frame0)
        self._notify_kiosk_result(material, confidence=0.96, image_filename=img_filename)

        # Başarılı sınıflandırma → UART komutu gönder
        if material in ("glass", "metal", "plastic", "paper"):
            self.uart_manager.send_command(material)
            # Cam tespitinde Supabase doluluk güncelle (diğer malzemelerde fiziksel sensör var)
            if self.bin_updater is not None and material == "glass":
                self.bin_updater.update_material("glass", increment_value=0.02)

        # Bekleme moduna geç
        self.state = "COOLDOWN"
        self.cooldown_start_time = time.time()
        self.still_counter = 0

        return material, explanation, inference_ms

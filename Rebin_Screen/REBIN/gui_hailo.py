#!/usr/bin/env python3
"""
gui_hailo.py
============
OpenCV tabanlı kamera önizleme modu — Hailo 8 AI HAT+ yerel model ile çalışır.
Groq API kullanımı tamamen kaldırılmıştır.
"""
import os
import sys

# SSH veya arka plandan çalıştırıldığında ekran değişkenlerini ayarla
if "DISPLAY" not in os.environ:
    os.environ["DISPLAY"] = ":0"
if "WAYLAND_DISPLAY" not in os.environ:
    os.environ["WAYLAND_DISPLAY"] = "wayland-0"
if "XDG_RUNTIME_DIR" not in os.environ:
    os.environ["XDG_RUNTIME_DIR"] = "/run/user/1000"

import time
import argparse
import numpy as np
import cv2

try:
    from inference_core import create_cameras, UARTManager
    from inference_hailo import HailoDetectorController
except ImportError as exc:
    print(f"Hata: Gerekli modüller içe aktarılamadı: {exc}", file=sys.stderr)
    sys.exit(1)


def build_canvas_hailo(
    frame0_bgr: np.ndarray,
    frame1_bgr: np.ndarray,
    fps: float,
    state: str,
    motion_ratio: float,
    api_status: str,
    last_material: str,
    roi_crop_ratios: tuple[float, float, float, float] = None,
    hef_loaded: bool = True,
) -> np.ndarray:
    """
    BGR karelerini 1280×700 (çift) veya 640×700 (tek) tuval üzerinde gösterir.
    Alta 60px bilgi çubuğu ekler. Çıkarım sırasında yarı saydam işleme katmanı çizer.
    """
    f0_display = frame0_bgr.copy()
    f1_display = frame1_bgr.copy() if frame1_bgr is not None else None

    # ROI kırpma dikdörtgeni çiz
    def draw_roi(frame, label):
        if roi_crop_ratios is not None and frame is not None:
            y1_r, y2_r, x1_r, x2_r = roi_crop_ratios
            h, w = frame.shape[:2]
            cv2.rectangle(
                frame,
                (int(x1_r * w), int(y1_r * h)),
                (int(x2_r * w), int(y2_r * h)),
                (0, 255, 255),
                1,
            )
            cv2.putText(
                frame,
                label,
                (int(x1_r * w) + 5, int(y1_r * h) + 15),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.4,
                (0, 255, 255),
                1,
                cv2.LINE_AA,
            )

    label0 = "ROI (NIR)" if f1_display is None else "ROI (RGB)"
    draw_roi(f0_display, label0)
    draw_roi(f1_display, "ROI (NoIR)")

    def pad_to_640(frame):
        h, w = frame.shape[:2]
        if h == 640 and w == 640:
            return frame
        padded = np.zeros((640, 640, 3), dtype=np.uint8)
        padded[(640 - h) // 2:(640 - h) // 2 + h,
               (640 - w) // 2:(640 - w) // 2 + w] = frame
        return padded

    if f1_display is not None:
        width = 1280
        img_section = np.hstack((pad_to_640(f0_display), pad_to_640(f1_display)))
    else:
        width = 640
        img_section = pad_to_640(f0_display)

    canvas = np.zeros((700, width, 3), dtype=np.uint8)
    canvas[0:640, 0:width] = img_section

    # Bilgi çubuğu
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 0.50
    color = (255, 255, 255)
    thickness = 1

    model_label = "Hailo 8 AI HAT+" if hef_loaded else "HAILO YAPILANDIRILAMADI"
    row1_text = (
        f"STATE: {state}   |   MOTION: {motion_ratio * 100:.2f}%   |   FPS: {fps:.1f}"
    )
    row2_text = (
        f"LAST: {last_material.upper()}   |   MODEL: {model_label}   |   {api_status}"
    )

    row1_size = cv2.getTextSize(row1_text, font, font_scale, thickness)[0]
    row2_size = cv2.getTextSize(row2_text, font, font_scale, thickness)[0]

    cv2.putText(
        canvas,
        row1_text,
        ((width - row1_size[0]) // 2, 665),
        font,
        font_scale,
        color,
        thickness,
        cv2.LINE_AA,
    )
    cv2.putText(
        canvas,
        row2_text,
        ((width - row2_size[0]) // 2, 690),
        font,
        font_scale,
        color,
        thickness,
        cv2.LINE_AA,
    )

    # Aktif kamera kenarlığı
    border_color = (0, 255, 0) if state == "WAIT_FOR_OBJECT" else (0, 200, 255)
    cv2.rectangle(canvas, (0, 0), (width, 640), border_color, 2)

    # Çift kamera bölücü çizgi
    if f1_display is not None:
        cv2.line(canvas, (640, 0), (640, 640), (100, 100, 100), 1)

    # Çıkarım sırasında yarı saydam katman
    if state == "REBIN_INFERENCE":
        overlay = canvas.copy()
        cv2.rectangle(overlay, (0, 0), (width, 640), (0, 0, 0), cv2.FILLED)
        cv2.addWeighted(overlay, 0.6, canvas, 0.4, 0, canvas)

        text = "HAILO 8 YEREL MODEL ANALIZ EDIYOR..."
        text_size = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 1)[0]
        cv2.putText(
            canvas,
            text,
            ((width - text_size[0]) // 2, (640 + text_size[1]) // 2),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (0, 200, 255),
            1,
            cv2.LINE_AA,
        )

    return canvas


def main():
    parser = argparse.ArgumentParser(
        description="Hailo 8 Yerel Model Geri Dönüşüm Dedektörü — GUI Modu"
    )
    parser.add_argument(
        "--hef-path",
        type=str,
        default=None,
        help="best_rebin.hef dosyasının tam yolu (bulunamazsa otomatik aranır)",
    )
    parser.add_argument(
        "--port",
        type=str,
        default="/dev/ttyACM0",
        help="Motor UART seri port yolu (varsayılan: /dev/ttyACM0)",
    )
    parser.add_argument(
        "--conf-threshold",
        type=float,
        default=0.50,
        help="Tespit güven eşiği 0-1 arası (varsayılan: 0.50)",
    )
    parser.add_argument(
        "--roi-crop",
        type=float,
        nargs=4,
        default=[0.1, 0.9, 0.15, 0.85],
        metavar=("Y1", "Y2", "X1", "X2"),
        help="Kamera ROI kırpma oranları (varsayılan: 0.1 0.9 0.15 0.85)",
    )
    parser.add_argument(
        "--settle-delay",
        type=float,
        default=3.0,
        help="Nesne konulduktan sonra çıkarım öncesi bekleme süresi (varsayılan: 3.0s)",
    )
    parser.add_argument(
        "--cooldown",
        type=float,
        default=5.0,
        help="Çıkarım sonrası bekleme süresi (varsayılan: 5.0s)",
    )
    parser.add_argument(
        "--still-threshold",
        type=float,
        default=0.015,
        help="Kare 'hareketsiz' kabul edilme eşiği (varsayılan: 0.015)",
    )
    parser.add_argument(
        "--motion-threshold",
        type=float,
        default=0.02,
        help="Hareket algılama tetikleme eşiği (varsayılan: 0.02)",
    )

    args = parser.parse_args()

    print("REBIN Geri Dönüşüm Dedektörü GUI Modu başlatılıyor...")
    print("Model: Hailo 8 AI HAT+ | best_rebin.hef")

    uart_manager = UARTManager(port=args.port)

    roi_crop_ratios = tuple(args.roi_crop) if args.roi_crop else None
    controller = HailoDetectorController(
        uart_manager=uart_manager,
        hef_path=args.hef_path,
        roi_crop_ratios=roi_crop_ratios,
        settle_delay=args.settle_delay,
        cooldown_time=args.cooldown,
        still_threshold=args.still_threshold,
        motion_threshold=args.motion_threshold,
        conf_threshold=args.conf_threshold,
    )

    cam0 = None
    cam1 = None
    try:
        print("NIR (NoIR) kamera başlatılıyor...")
        cam0, cam1 = create_cameras(single_rgb_only=False, use_noir_only=True)
        print("NIR (NoIR) kamera başarıyla başlatıldı.")
    except Exception as exc:
        print(f"FATAL: Kamera başlatılamadı: {exc}", file=sys.stderr)
        uart_manager.close()
        sys.exit(1)

    WINDOW_TITLE = "REBIN Recycling Detector — Hailo 8"
    cv2.namedWindow(WINDOW_TITLE, cv2.WINDOW_NORMAL)

    print("Sistem hazır. İlk arka plan kalibre ediliyor...")
    time.sleep(1.0)
    try:
        frame0_bgr = cam0.capture_array()
        frame0 = frame0_bgr[..., ::-1].copy()
        controller.reset_background(frame0)
    except Exception as exc:
        print(f"Uyarı: Kalibrasyon karesi alınamadı: {exc}", file=sys.stderr)

    total_cycles = 0
    start_time = time.perf_counter()

    print(
        "GUI penceresi açıldı. Çıkmak için OpenCV penceresinde 'q' tuşuna veya "
        "terminalde Ctrl+C'ye basın."
    )

    try:
        while True:
            t0 = time.perf_counter()

            frame0_bgr = cam0.capture_array()
            frame1_bgr = cam1.capture_array() if cam1 is not None else None

            frame0 = frame0_bgr[..., ::-1].copy()
            frame1 = frame1_bgr[..., ::-1].copy() if frame1_bgr is not None else None

            trigger_api = controller.process_frame(frame0, frame1)

            t1 = time.perf_counter()
            fps = 1.0 / max(t1 - t0, 1e-5)

            canvas = build_canvas_hailo(
                frame0_bgr,
                frame1_bgr,
                fps,
                controller.state,
                controller.last_motion_ratio,
                controller.last_api_status,
                controller.last_material,
                controller.roi_crop_ratios,
                hef_loaded=controller.classifier.is_configured,
            )
            cv2.imshow(WINDOW_TITLE, canvas)
            total_cycles += 1

            if trigger_api:
                canvas = build_canvas_hailo(
                    frame0_bgr,
                    frame1_bgr,
                    fps,
                    "REBIN_INFERENCE",
                    controller.last_motion_ratio,
                    "Hailo 8 çıkarımı çalıştırılıyor...",
                    controller.last_material,
                    controller.roi_crop_ratios,
                    hef_loaded=controller.classifier.is_configured,
                )
                cv2.imshow(WINDOW_TITLE, canvas)
                cv2.waitKey(1)
                controller.run_api_classification(frame0, frame1)

            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    except KeyboardInterrupt:
        print("\nDedektör durduruluyor ve pencere kapatılıyor...")
    finally:
        cv2.destroyAllWindows()
        for cam_obj in (cam0, cam1):
            if cam_obj is not None:
                try:
                    cam_obj.stop()
                except Exception:
                    pass
        try:
            uart_manager.close()
        except Exception:
            pass

        elapsed = time.perf_counter() - start_time
        print("\n================== Sistem İstatistikleri ==================")
        print(f"Toplam Çalışma Süresi : {elapsed:.2f} saniye")
        print(f"İşlenen Kare Sayısı   : {total_cycles}")
        if elapsed > 0:
            print(f"Ortalama Döngü Hızı   : {total_cycles / elapsed:.2f} Hz")
        print("===========================================================")


if __name__ == "__main__":
    main()

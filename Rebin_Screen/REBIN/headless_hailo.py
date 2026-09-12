#!/usr/bin/env python3
"""
headless_hailo.py
=================
Terminal canlı gösterge tablosu ve Hailo 8 AI HAT+ kontrolcüsü.
Groq API kullanımı tamamen kaldırılmıştır; tüm çıkarım yerel modelle yapılır.
"""
import os
import sys
import logging

# Başlangıç loglarını/uyarıları bastırmak için orijinal stdout/stderr'i sakla
_orig_stdout = sys.stdout
_orig_stderr = sys.stderr

_devnull = open(os.devnull, "w")
sys.stdout = _devnull
sys.stderr = _devnull

# Gereksiz log seviyelerini kapat
os.environ["ORT_LOGGING_LEVEL"] = "3"
os.environ["LIBCAMERA_LOG_LEVELS"] = "3"
logging.disable(logging.INFO)

import time
import argparse
from datetime import datetime

try:
    from inference_core import create_cameras, UARTManager
    from inference_hailo import HailoDetectorController
except ImportError as exc:
    sys.stdout = _orig_stdout
    sys.stderr = _orig_stderr
    print(f"Hata: Gerekli modüller içe aktarılamadı: {exc}", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Hailo 8 Yerel Model Geri Dönüşüm Dedektörü — Headless Mod"
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
        "--no-color",
        action="store_true",
        help="Loglama için düz metin çıktısı (Rich tablo olmadan)",
    )
    parser.add_argument(
        "--roi-crop",
        type=float,
        nargs=4,
        default=None,
        metavar=("Y1", "Y2", "X1", "X2"),
        help="Kamera ROI kırpma oranları, örn: --roi-crop 0.05 0.95 0.05 0.95",
    )
    parser.add_argument(
        "--settle-delay",
        type=float,
        default=1.5,
        help="Nesne konulduktan sonra çıkarım öncesi bekleme süresi (varsayılan: 1.5s)",
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

    # Olay işleyici ve son olaylar kaydı
    recent_events: list[str] = []
    init_time_str = datetime.now().strftime("%H:%M:%S")
    recent_events.append(f"[{init_time_str}] Sistem hazir. Sensorler izlemede.")

    def handle_event(event_type: str, data):
        now_str = datetime.now().strftime("%H:%M:%S")
        if event_type == "MOTION_DETECTED":
            recent_events.append(f"[{now_str}] Hareket algilandi (Durulma bekleniyor)")
            if args.no_color:
                print(
                    f"[{now_str}] [HAREKET] Tepside hareket algilandi "
                    f"(%{data * 100:.1f}). Durulma bekleniyor...",
                    flush=True,
                )
        elif event_type == "INFERENCE_STARTED":
            recent_events.append(f"[{now_str}] Hailo 8 yerel model analizi baslatildi...")
            if args.no_color:
                print(
                    f"[{now_str}] [AI] Hailo 8 yerel model analizi baslatiliyor...",
                    flush=True,
                )
        elif event_type == "CLASSIFICATION_RESULT":
            mat = data["material"].upper()
            lat = data["latency"]
            recent_events.append(f"[{now_str}] Tespit: {mat} ({lat:.0f}ms)")
            if args.no_color:
                print(
                    f"[{now_str}] [SONUC] Malzeme: {mat} ({data['explanation']}) "
                    f"| Sure: {lat:.0f}ms",
                    flush=True,
                )
                if data["material"] in ("glass", "metal", "plastic", "paper"):
                    cmd = {"glass": "C", "metal": "M", "plastic": "P", "paper": "K"}.get(
                        data["material"]
                    )
                    print(
                        f"[{now_str}] [ESP32] Komut '{cmd}' iletildi "
                        f"({data['material'].capitalize()} haznesi).",
                        flush=True,
                    )
                    if controller.bin_updater is not None:
                        print(
                            f"[{now_str}] [BULUT] Supabase doluluk guncellendi (+0.02).",
                            flush=True,
                        )
                print(
                    f"[{now_str}] [BEKLEME] {controller.cooldown_time:.1f}s "
                    f"bekleme suresi baslatildi.\n",
                    flush=True,
                )
        elif event_type == "TRAY_CLEARED":
            recent_events.append(f"[{now_str}] Tepsi temizlendi. Yeni atik bekleniyor.")
            if args.no_color:
                print(
                    f"[{now_str}] [HAZIR] Tepsi temizlendi ve kalibre edildi. "
                    f"Yeni atik bekleniyor.",
                    flush=True,
                )
        elif event_type == "TRAY_EMPTY_SKIPPED":
            if args.no_color:
                print(
                    f"[{now_str}] [BILGI] Tepsi bos algilandi, analiz atlandi.",
                    flush=True,
                )

        while len(recent_events) > 3:
            recent_events.pop(0)

    # UART başlat
    uart_manager = UARTManager(port=args.port)

    # Kontrolcüyü başlat
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
        on_event=handle_event,
    )

    cam0 = None
    cam1 = None
    try:
        cam0, cam1 = create_cameras(single_rgb_only=False, use_noir_only=True)
        # Kamera sensörü ısınması (otomatik pozlama ve beyaz dengesi için)
        for _ in range(8):
            cam0.capture_array()
            if cam1 is not None:
                cam1.capture_array()
            time.sleep(0.04)

        warmup_bgr = cam0.capture_array()
        controller.reset_background(warmup_bgr[..., ::-1].copy())
    except Exception as exc:
        sys.stdout = _orig_stdout
        sys.stderr = _orig_stderr
        print(f"FATAL: Kamera başlatılamadı: {exc}", file=sys.stderr)
        uart_manager.close()
        sys.exit(1)

    # Orijinal stdout'a geri dön
    sys.stdout = _orig_stdout
    if args.no_color:
        sys.stderr = _orig_stderr
    else:
        sys.stderr = _devnull

    hef_status = (
        f"Yüklendi ({controller.classifier._hef_path})"
        if controller.classifier.is_configured
        else "YAPILANDIRILAMADI — UNKNOWN döndürülecek"
    )

    if args.no_color:
        print("============================================================")
        print("      REBIN Akilli Geri Donusum Dedektoru (Headless)        ")
        print("============================================================")
        print("Kamera  : NIR IMX708 NoIR (Aktif, 2.10x Zoom)")
        print(f"Model   : Hailo 8 AI HAT+ | best_rebin.hef | {hef_status}")
        print(
            f"UART    : {uart_manager.port} "
            f"({'Bagli' if uart_manager.is_connected else 'Standalone/Simulasyon'})"
        )
        print(
            f"Cloud   : "
            f"{'Supabase Cloud Database Aktif (pbin_0001)' if controller.bin_updater is not None else 'Devre Disi'}"
        )
        print("============================================================")
        print("Sistem izlemede. Nesne tepsisine atik koyuldugunda algilanacaktir.")
        print("Durdurmak icin: Ctrl+C\n")

    if not sys.stdout.isatty():
        args.no_color = True

    if not args.no_color:
        try:
            from rich.live import Live
        except ImportError:
            args.no_color = True

    total_cycles = 0
    start_time = time.perf_counter()
    last_api_latency = 0.0

    try:
        if args.no_color:
            while True:
                frame0_bgr = cam0.capture_array()
                frame1_bgr = cam1.capture_array() if cam1 is not None else None

                frame0 = frame0_bgr[..., ::-1].copy()
                frame1 = frame1_bgr[..., ::-1].copy() if frame1_bgr is not None else None

                trigger_api = controller.process_frame(frame0, frame1)
                if trigger_api:
                    controller.run_api_classification(frame0, frame1)

                time.sleep(0.025)
                total_cycles += 1
        else:
            with Live(auto_refresh=False) as live:
                while True:
                    t0 = time.perf_counter()

                    frame0_bgr = cam0.capture_array()
                    frame1_bgr = cam1.capture_array() if cam1 is not None else None

                    frame0 = frame0_bgr[..., ::-1].copy()
                    frame1 = frame1_bgr[..., ::-1].copy() if frame1_bgr is not None else None

                    trigger_api = controller.process_frame(frame0, frame1)

                    if trigger_api:
                        live.update(
                            build_table(controller, 0.0, recent_events, last_api_latency),
                            refresh=True,
                        )
                        _, _, api_time = controller.run_api_classification(frame0, frame1)
                        last_api_latency = api_time

                    t1 = time.perf_counter()
                    fps = 1.0 / max(t1 - t0, 1e-5)

                    live.update(
                        build_table(controller, fps, recent_events, last_api_latency),
                        refresh=True,
                    )
                    time.sleep(0.025)
                    total_cycles += 1

    except KeyboardInterrupt:
        sys.stdout = _orig_stdout
        sys.stderr = _orig_stderr
        print("\n[INFO] REBIN sistemi guvenli sekilde durduruluyor...")
    finally:
        sys.stdout = _orig_stdout
        sys.stderr = _orig_stderr
        for cam_obj in (cam0, cam1):
            if cam_obj is not None:
                try:
                    cam_obj.stop()
                    cam_obj.close()
                except Exception:
                    pass
        try:
            uart_manager.close()
        except Exception:
            pass

        elapsed = time.perf_counter() - start_time
        print("\n================== REBIN SISTEM ISTATISTIKLERI ==================")
        print(f"Toplam Calisma Suresi : {elapsed:.2f} saniye")
        print(f"Islenen Kare Sayisi   : {total_cycles}")
        if elapsed > 0:
            print(f"Ortalama Hiz          : {total_cycles / elapsed:.1f} FPS")
        print("=================================================================\n")


def build_table(controller, fps: float, recent_events=None, last_latency: float = 0.0):
    from rich.table import Table

    state_styles = {
        "WAIT_FOR_OBJECT": "[bold green]BEKLEMEDE (NESNE BEKLENIYOR)[/bold green]",
        "OBJECT_PLACING": "[bold yellow]NESNE ALGILANDI (DURULMA BEKLENIYOR)[/bold yellow]",
        "REBIN_INFERENCE": "[bold blink bright_cyan]HAILO 8 ANALIZ EDIYOR...[/bold blink bright_cyan]",
        "COOLDOWN": "[bold blue]BEKLEME / MOTOR COOLDOWN[/bold blue]",
    }
    state_str = state_styles.get(controller.state, controller.state)

    mat_map = {
        "glass":   "[bold bright_cyan]🍸 CAM (GLASS) -> Kapak 'C'[/bold bright_cyan]",
        "metal":   "[bold bright_white]🥫 METAL -> Kapak 'M'[/bold bright_white]",
        "plastic": "[bold yellow]🥤 PLASTIK (PLASTIC) -> Kapak 'P'[/bold yellow]",
        "paper":   "[bold green]📦 KAGIT (PAPER) -> Kapak 'K'[/bold green]",
        "unknown": "[bold red]❓ BILINMEYEN / BOS TEPSI[/bold red]",
        "None":    "[dim]-- Bos / Hazir --[/dim]",
    }
    mat_display = mat_map.get(
        controller.last_material.lower(), controller.last_material.upper()
    )

    hef_loaded = controller.classifier.is_configured
    model_status = (
        "[bold green]Hailo 8 AI HAT+ (best_rebin.hef)[/bold green]"
        if hef_loaded
        else "[bold red]YAPILANDIRILAMADI — UNKNOWN modu[/bold red]"
    )

    esp32_status = (
        f"[bold green]Bagli ({controller.uart_manager.port})[/bold green]"
        if controller.uart_manager.is_connected
        else "[yellow]Standalone / Hazir[/yellow]"
    )
    cloud_status = (
        "[bold green]Cevrimici (Supabase / pbin_0001)[/bold green]"
        if controller.bin_updater is not None
        else "[dim]Devre Disi[/dim]"
    )

    table = Table(
        title=(
            f"♻️  REBIN Akilli Geri Donusum Dedektoru  |  {fps:.1f} FPS  |  Cikis: Ctrl+C"
        ),
        title_style="bold bright_green",
        caption=f"Durum: {controller.last_api_status}",
        caption_justify="center",
    )
    table.add_column("Sistem Parametresi", style="cyan", justify="left", width=22)
    table.add_column("Canli Durum / Deger", justify="left")

    table.add_row("Sistem Durumu", state_str)
    table.add_row("Hareket Orani", f"%{controller.last_motion_ratio * 100:.2f}")
    table.add_row("Kamera Baglantisi", "NIR IMX708 NoIR (Aktif, 2.10x Zoom)")
    table.add_row("Yapay Zeka Modeli", model_status)
    table.add_row("ESP32 Donanimi", esp32_status)
    table.add_row("Bulut Veritabani", cloud_status)
    table.add_row("Son Tespit Edilen", mat_display)
    if last_latency > 0:
        table.add_row("Inference Suresi", f"{last_latency:.0f} ms")
    if recent_events:
        table.add_row("Son Olay", f"[dim]{recent_events[-1]}[/dim]")

    return table


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
REBIN Touch Display Kiosk Server
Serves the 1280x720 Kiosk UI, proxies Supabase data, manages local waste images,
and provides real-time Server-Sent Events (SSE) for camera and classification events.
"""

import os
import sys
import re
import json
import time
import datetime
import mimetypes
import threading
import urllib.request
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

try:
    import serial
except ImportError:
    serial = None

# ---------------------------------------------------------------------------
# Configuration & Environment
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(BASE_DIR, ".env")

CONFIG = {
    "SUPABASE_URL": "https://spmyeaixfdiohkmmfvgu.supabase.co",
    "SUPABASE_ANON_KEY": "",
    "BIN_ID": "pbin_0001",
    "HOST": "0.0.0.0",
    "PORT": 8080,
    "IDLE_INTERVAL_SECONDS": 5,
    "IDLE_TIMEOUT_TO_HOME_SECONDS": 30,
    "OCCUPANCY_SENSOR_PORT": "/dev/ttyUSB0",
    "OCCUPANCY_SENSOR_BAUD": 115200,
    "LOCAL_IMAGE_DIR": os.path.join(BASE_DIR, "data", "waste_images"),
    "RECORDS_FILE": os.path.join(BASE_DIR, "data", "waste_records.json"),
    "ISSUES_FILE": os.path.join(BASE_DIR, "data", "reported_issues.json"),
}

def load_env():
    """Loads configuration from .env file if present."""
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip().strip("'").strip('"')
                CONFIG[k] = v

load_env()
os.makedirs(CONFIG["LOCAL_IMAGE_DIR"], exist_ok=True)
os.makedirs(os.path.dirname(CONFIG["RECORDS_FILE"]), exist_ok=True)

# ---------------------------------------------------------------------------
# SSE Event Broadcaster
# ---------------------------------------------------------------------------
class EventBroadcaster:
    def __init__(self):
        self.clients = []
        self.lock = threading.Lock()

    def register(self, client_queue):
        with self.lock:
            self.clients.append(client_queue)

    def unregister(self, client_queue):
        with self.lock:
            if client_queue in self.clients:
                self.clients.remove(client_queue)

    def broadcast(self, event_type, data):
        payload = f"event: {event_type}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"
        with self.lock:
            for q in list(self.clients):
                try:
                    q.put_nowait(payload)
                except Exception:
                    pass

broadcaster = EventBroadcaster()

# ---------------------------------------------------------------------------
# Supabase Integration Helper
# ---------------------------------------------------------------------------
def fetch_bin_data_from_supabase():
    """Queries Supabase REST API for the current bin's occupancy and details."""
    supabase_url = CONFIG["SUPABASE_URL"].rstrip("/")
    key = CONFIG["SUPABASE_ANON_KEY"]
    bin_id = CONFIG["BIN_ID"]

    if not supabase_url or not key:
        return None

    query_url = f"{supabase_url}/rest/v1/rebins?bin_id=eq.{urllib.parse.quote(bin_id)}&select=*"
    req = urllib.request.Request(
        query_url,
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data and len(data) > 0:
                bin_info = data[0]
                # Calculate general overall occupancy average
                glass = float(bin_info.get("occupancy_glass") or 0.0)
                metal = float(bin_info.get("occupancy_metal") or 0.0)
                paper = float(bin_info.get("occupancy_paper") or 0.0)
                plastic = float(bin_info.get("occupancy_plastic") or 0.0)
                general = (glass + metal + paper + plastic) / 4.0
                bin_info["general"] = round(general, 4)
                return bin_info
    except Exception as e:
        print(f"[Supabase Sync] Warning: Could not fetch from Supabase ({e}). Using local fallback.", file=sys.stderr)
    return None

def get_cached_or_default_bin():
    """Provides fallback bin information if network or Supabase is unavailable."""
    return {
        "bin_id": CONFIG["BIN_ID"],
        "name": "REBIN",
        "type": "private",
        "is_active": True,
        "occupancy_glass": 0.04,
        "occupancy_metal": 0.04,
        "occupancy_paper": 0.06,
        "occupancy_plastic": 0.02,
        "general": 0.04,
        "last_emptying": "2026-06-16T11:00:00+00:00",
        "last_updated": datetime.datetime.now().isoformat(),
        "qr_image_url": "/assets/pbin_0001.png",
        "semt": "Avcılar"
    }

# ---------------------------------------------------------------------------
# Local Waste Image & Record Management
# ---------------------------------------------------------------------------
def get_local_waste_records():
    """Reads the local JSON metadata file and checks available image files."""
    records_file = CONFIG["RECORDS_FILE"]
    records = []
    if os.path.exists(records_file):
        try:
            with open(records_file, "r", encoding="utf-8") as f:
                records = json.load(f)
        except Exception as e:
            print(f"[Records] Error reading {records_file}: {e}", file=sys.stderr)
            records = []

    # Map image paths to web accessible URL
    formatted = []
    for r in records:
        filename = r.get("image_filename", "")
        filepath = os.path.join(CONFIG["LOCAL_IMAGE_DIR"], filename)
        if os.path.exists(filepath):
            item = dict(r)
            item["image_url"] = f"/data/waste_images/{filename}"
            formatted.append(item)

    # Sort newest first
    formatted.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return formatted

def add_waste_record(waste_type, confidence, image_filename):
    """Saves a new classification entry to the local records file."""
    records_file = CONFIG["RECORDS_FILE"]
    records = []
    if os.path.exists(records_file):
        try:
            with open(records_file, "r", encoding="utf-8") as f:
                records = json.load(f)
        except Exception:
            records = []

    new_record = {
        "id": f"rec_{int(time.time()*1000)}",
        "image_filename": image_filename,
        "waste_type": waste_type,
        "confidence": float(confidence),
        "created_at": datetime.datetime.now().isoformat()
    }
    records.insert(0, new_record)

    try:
        with open(records_file, "w", encoding="utf-8") as f:
            json.dump(records, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[Records] Error writing record: {e}", file=sys.stderr)

    return new_record

def save_reported_issue(issue_text, error_type="error_4"):
    """Stores user problem reports to local file and logs it."""
    issues_file = CONFIG["ISSUES_FILE"]
    issues = []
    if os.path.exists(issues_file):
        try:
            with open(issues_file, "r", encoding="utf-8") as f:
                issues = json.load(f)
        except Exception:
            issues = []

    report = {
        "id": f"issue_{int(time.time()*1000)}",
        "bin_id": CONFIG["BIN_ID"],
        "issue": issue_text,
        "error_type": error_type,
        "created_at": datetime.datetime.now().isoformat(),
        "status": "pending"
    }
    issues.insert(0, report)

    try:
        with open(issues_file, "w", encoding="utf-8") as f:
            json.dump(issues, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[Issues] Error saving issue: {e}", file=sys.stderr)

    return report

def report_bin_error_to_supabase(bin_id, error_type="error_4"):
    """
    Updates the Supabase 'bin_errors' table for the specified bin_id.
    1. Reads existing row for bin_id:
       GET /rest/v1/bin_errors?bin_id=eq.{bin_id}&select=*
    2. Upsert/Increment Logic:
       - Durum A (Satır Yoksa): Insert new row with clicked error = 1, others = 0.
       - Durum B (Satır Varsa): Update row with clicked error = currentVal + 1 and last_reported_at = now.
    """
    supabase_url = CONFIG["SUPABASE_URL"].rstrip("/")
    key = CONFIG["SUPABASE_ANON_KEY"]

    if not supabase_url or not key:
        print("[Supabase bin_errors] Warning: Supabase credentials not set in server.", file=sys.stderr)
        return {"success": False, "error": "Supabase credentials missing"}

    valid_error_keys = {"error_1", "error_2", "error_3", "error_4"}
    if error_type not in valid_error_keys:
        error_type = "error_4"

    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    try:
        # 1. Kontrol ve Okuma
        query_url = f"{supabase_url}/rest/v1/bin_errors?bin_id=eq.{urllib.parse.quote(bin_id)}&select=*"
        req = urllib.request.Request(query_url, headers=headers)
        
        row = None
        try:
            with urllib.request.urlopen(req, timeout=5.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if data and isinstance(data, list) and len(data) > 0:
                    row = data[0]
        except Exception as e:
            print(f"[Supabase bin_errors] Select check error: {e}", file=sys.stderr)
            row = None

        if row is None:
            # Durum A: Satır Yoksa -> Insert
            insert_payload = {
                "bin_id": bin_id,
                "error_1": 1 if error_type == "error_1" else 0,
                "error_2": 1 if error_type == "error_2" else 0,
                "error_3": 1 if error_type == "error_3" else 0,
                "error_4": 1 if error_type == "error_4" else 0,
                "last_reported_at": now_iso
            }
            insert_url = f"{supabase_url}/rest/v1/bin_errors"
            insert_bytes = json.dumps(insert_payload).encode("utf-8")
            post_req = urllib.request.Request(
                insert_url,
                data=insert_bytes,
                headers={**headers, "Prefer": "return=representation"},
                method="POST"
            )
            with urllib.request.urlopen(post_req, timeout=5.0) as resp:
                res_data = json.loads(resp.read().decode("utf-8"))
                print(f"[Supabase bin_errors] Yeni satır oluşturuldu: {res_data}")
                return {"success": True, "action": "inserted", "data": res_data}
        else:
            # Durum B: Satır Varsa -> Increment clicked error
            current_val = int(row.get(error_type) or 0)
            new_val = current_val + 1
            update_payload = {
                error_type: new_val,
                "last_reported_at": now_iso
            }
            update_url = f"{supabase_url}/rest/v1/bin_errors?bin_id=eq.{urllib.parse.quote(bin_id)}"
            update_bytes = json.dumps(update_payload).encode("utf-8")
            patch_req = urllib.request.Request(
                update_url,
                data=update_bytes,
                headers={**headers, "Prefer": "return=representation"},
                method="PATCH"
            )
            with urllib.request.urlopen(patch_req, timeout=5.0) as resp:
                res_data = json.loads(resp.read().decode("utf-8"))
                print(f"[Supabase bin_errors] '{bin_id}' güncellendi: {error_type} = {new_val}")
                return {"success": True, "action": "updated", "data": res_data}

    except Exception as e:
        print(f"[Supabase bin_errors] Failed to update bin_errors in Supabase: {e}", file=sys.stderr)
        return {"success": False, "error": str(e)}

# ---------------------------------------------------------------------------
# Real-Time Physical Occupancy Sensor Reader (/dev/ttyUSB0)
# ---------------------------------------------------------------------------
class OccupancySensorReader:
    """
    Background thread that continuously reads real-time occupancy and distance measurements
    from the physical sensors connected via USB-UART (/dev/ttyUSB0 at 115200 baud).
    Maps incoming lines for 'Kagit' (Paper), 'Metal' (Metal), and 'Plastik' (Plastic).
    Glass ('Cam') is simulated via inference detections.
    """
    def __init__(self, port="/dev/ttyUSB0", baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.running = False
        self.thread = None
        self.lock = threading.Lock()

        # Real-time state per compartment
        self.occupancies = {
            "paper": None,    # Float 0.0 - 1.0 (e.g. 0.04 for 4%)
            "metal": None,    # Float 0.0 - 1.0 (e.g. 0.11 for 11%)
            "plastic": None,  # Float 0.0 - 1.0 (e.g. 0.08 for 8%)
        }
        self.distances = {
            "paper": None,    # Float cm (e.g. 40.2)
            "metal": None,    # Float cm (e.g. 37.0)
            "plastic": None,  # Float cm (e.g. 38.4)
        }
        self.last_update_times = {
            "paper": 0.0,
            "metal": 0.0,
            "plastic": 0.0,
        }
        self.last_update_time = 0.0
        self.is_connected = False

        # Supabase sync debounce
        self.last_synced_occupancies = {}
        self.last_sync_time = 0.0
        self.last_sync_attempt = 0.0
        self.sync_lock = threading.Lock()

    def start(self):
        if self.running:
            return
        self.running = True
        self.thread = threading.Thread(target=self._read_loop, name="OccupancySensorReader", daemon=True)
        self.thread.start()
        print(f"[OccupancySensor] Multi-sensor reader thread started on {self.port} ({self.baudrate} baud).")

    def stop(self):
        self.running = False

    def get_occupancies(self):
        with self.lock:
            return dict(self.occupancies)

    def get_distances(self):
        with self.lock:
            return dict(self.distances)

    def get_status(self):
        with self.lock:
            return {
                "port": self.port,
                "baudrate": self.baudrate,
                "connected": self.is_connected,
                "occupancies": dict(self.occupancies),
                "distances_cm": dict(self.distances),
                "last_update_age_sec": round(time.time() - self.last_update_time, 1) if self.last_update_time else None
            }

    @staticmethod
    def _normalize_material_name(raw_name: str) -> str:
        s = raw_name.strip().lower()
        if "kagit" in s or "kağit" in s or "kağıt" in s:
            return "paper"
        elif "metal" in s:
            return "metal"
        elif "plastik" in s or "plastic" in s:
            return "plastic"
        return s

    def _read_loop(self):
        if serial is None:
            print("[OccupancySensor] Error: 'pyserial' is not installed. Occupancy sensor cannot be read.", file=sys.stderr)
            return

        # Pattern: Kagit/Metal/Plastik -> Mesafe: XX.X cm | Doluluk: %X
        sensor_pattern = re.compile(
            r"(Kagit|Ka[gğ]it|Metal|Plastik)\s*->\s*Mesafe:\s*([\d\.]+)\s*cm\s*\|\s*Doluluk:\s*%?\s*(\d+)",
            re.IGNORECASE
        )

        while self.running:
            ser = None
            try:
                ser = serial.Serial(self.port, self.baudrate, timeout=1.0)
                with self.lock:
                    self.is_connected = True
                print(f"[OccupancySensor] Connected to multi-sensor stream on {self.port}.")

                while self.running:
                    line_bytes = ser.readline()
                    if not line_bytes:
                        continue
                    line = line_bytes.decode("utf-8", errors="ignore").strip()
                    if not line or line.startswith("="):
                        continue

                    match = sensor_pattern.search(line)
                    if match:
                        mat_key = self._normalize_material_name(match.group(1))
                        try:
                            dist_val = float(match.group(2))
                            pct = int(match.group(3))
                            occ_val = round(max(0.0, min(1.0, pct / 100.0)), 4)

                            with self.lock:
                                self.occupancies[mat_key] = occ_val
                                self.distances[mat_key] = dist_val
                                self.last_update_times[mat_key] = time.time()
                                self.last_update_time = time.time()

                            self._maybe_sync_supabase()
                        except (ValueError, IndexError):
                            pass

            except Exception as e:
                with self.lock:
                    self.is_connected = False
                print(f"[OccupancySensor] Port {self.port} error: {e}. Retrying in 3s...", file=sys.stderr)
                time.sleep(3.0)
            finally:
                if ser and ser.is_open:
                    try:
                        ser.close()
                    except Exception:
                        pass

    def _maybe_sync_supabase(self):
        now = time.time()
        with self.sync_lock:
            # Throttle sync attempts: max once every 3 seconds
            if now - self.last_sync_attempt < 3.0:
                return

            with self.lock:
                current_occs = dict(self.occupancies)

            # Wait until at least one sensor has data
            active_vals = {k: v for k, v in current_occs.items() if v is not None}
            if not active_vals:
                return

            should_sync = False
            if not self.last_synced_occupancies:
                # First sync
                should_sync = True
            else:
                # Check if any material value changed by >= 1%
                for mat, val in active_vals.items():
                    last_val = self.last_synced_occupancies.get(mat)
                    if last_val is None or abs(val - last_val) >= 0.01:
                        should_sync = True
                        break
                # Periodic heartbeat sync (every 30 seconds)
                if not should_sync and (now - self.last_sync_time >= 30.0):
                    should_sync = True

            if should_sync:
                self.last_synced_occupancies = dict(current_occs)
                self.last_sync_time = now
                self.last_sync_attempt = now
                threading.Thread(target=self._push_to_supabase, args=(dict(active_vals),), daemon=True).start()

    def _push_to_supabase(self, occs_to_push):
        try:
            supabase_url = CONFIG.get("SUPABASE_URL", "").rstrip("/")
            key = CONFIG.get("SUPABASE_ANON_KEY", "")
            bin_id = CONFIG.get("BIN_ID", "pbin_0001")
            if not supabase_url or not key:
                return

            patch_url = f"{supabase_url}/rest/v1/rebins?bin_id=eq.{urllib.parse.quote(bin_id)}"
            payload = {
                "last_updated": datetime.datetime.now(datetime.timezone.utc).isoformat()
            }
            for mat, val in occs_to_push.items():
                payload[f"occupancy_{mat}"] = val

            req = urllib.request.Request(
                patch_url,
                data=json.dumps(payload).encode("utf-8"),
                headers={
                    "apikey": key,
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                    "Prefer": "return=minimal"
                },
                method="PATCH"
            )
            with urllib.request.urlopen(req, timeout=4.0) as resp:
                if resp.status in (200, 204):
                    summary = ", ".join(f"{k}: {v*100:.0f}%" for k, v in occs_to_push.items())
                    print(f"[OccupancySensor] Synced to Supabase: {summary}")
        except Exception as e:
            print(f"[OccupancySensor] Supabase sync warning: {e}", file=sys.stderr)

sensor_reader = OccupancySensorReader(
    port=CONFIG.get("OCCUPANCY_SENSOR_PORT", "/dev/ttyUSB0"),
    baudrate=int(CONFIG.get("OCCUPANCY_SENSOR_BAUD", 115200))
)

# ---------------------------------------------------------------------------
# HTTP Request Handler
# ---------------------------------------------------------------------------
class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

class KioskHTTPRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Quiet standard logging to avoid filling terminal
        if self.path.startswith("/api/events"):
            return
        super().log_message(format, *args)

    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        # 1. API: Bin Info (Supabase + Local fallback)
        if path == "/api/bin-info":
            data = fetch_bin_data_from_supabase()
            if not data:
                data = get_cached_or_default_bin()

            # Override paper, metal, plastic occupancies with live physical sensor readings (/dev/ttyUSB0)
            sensor_occs = sensor_reader.get_occupancies()
            sensor_dists = sensor_reader.get_distances()

            for mat in ("paper", "metal", "plastic"):
                if sensor_occs.get(mat) is not None:
                    data[f"occupancy_{mat}"] = sensor_occs[mat]
                if sensor_dists.get(mat) is not None:
                    data[f"sensor_{mat}_distance_cm"] = sensor_dists[mat]

            # Glass is simulated, value is preserved from Supabase / cache
            glass = float(data.get("occupancy_glass") or 0.0)
            metal = float(data.get("occupancy_metal") or 0.0)
            paper = float(data.get("occupancy_paper") or 0.0)
            plastic = float(data.get("occupancy_plastic") or 0.0)
            data["general"] = round((glass + metal + paper + plastic) / 4.0, 4)

            # Check if user added custom logo or bottle
            data["has_custom_logo"] = os.path.exists(os.path.join(BASE_DIR, "static", "assets", "logo.png")) or \
                                      os.path.exists(os.path.join(BASE_DIR, "logo.png")) or \
                                      os.path.exists(os.path.join(BASE_DIR, "rebin_logo.png"))
            data["has_custom_bottle"] = os.path.exists(os.path.join(BASE_DIR, "static", "assets", "pet_bottle.png")) or \
                                        os.path.exists(os.path.join(BASE_DIR, "pet_bottle.png")) or \
                                        os.path.exists(os.path.join(BASE_DIR, "pet_sise.png"))

            body = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
            return

        # 2. API: Local Waste Images & Records
        if path == "/api/waste-images":
            records = get_local_waste_records()
            body = json.dumps({"records": records}, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
            return

        # 3. API: Status
        if path == "/api/status":
            status_data = {
                "status": "online",
                "bin_id": CONFIG["BIN_ID"],
                "time": datetime.datetime.now().isoformat(),
                "resolution": "1280x720",
                "idle_interval": int(CONFIG["IDLE_INTERVAL_SECONDS"]),
                "occupancy_sensor": sensor_reader.get_status()
            }
            body = json.dumps(status_data).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
            return

        # 4. API: Server-Sent Events (SSE) for Real-Time Triggering
        if path == "/api/events":
            import queue
            client_q = queue.Queue()
            broadcaster.register(client_q)

            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache, no-transform")
            self.send_header("Connection", "keep-alive")
            self.send_cors_headers()
            self.end_headers()

            # Send initial connected event
            init_msg = f"event: connected\ndata: {json.dumps({'status': 'ready'})}\n\n"
            self.wfile.write(init_msg.encode("utf-8"))
            self.wfile.flush()

            try:
                while True:
                    try:
                        msg = client_q.get(timeout=20.0)
                        self.wfile.write(msg.encode("utf-8"))
                        self.wfile.flush()
                    except queue.Empty:
                        # Keep-alive heartbeat comment
                        self.wfile.write(b": heartbeat\n\n")
                        self.wfile.flush()
            except Exception:
                pass
            finally:
                broadcaster.unregister(client_q)
            return

        # 5. Serving Local Waste Images (/data/waste_images/...)
        if path.startswith("/data/waste_images/"):
            filename = os.path.basename(path)
            filepath = os.path.join(CONFIG["LOCAL_IMAGE_DIR"], filename)
            if os.path.exists(filepath) and os.path.isfile(filepath):
                self.serve_file(filepath)
                return
            else:
                self.send_error(404, "Waste Image Not Found")
                return

        # 6. Static File Serving (/static/...)
        if path == "/" or path == "/index.html":
            target = os.path.join(BASE_DIR, "static", "index.html")
        else:
            rel_path = path.lstrip("/")
            # Check if requesting directly from static folder or root
            if rel_path.startswith("static/"):
                target = os.path.join(BASE_DIR, rel_path)
            else:
                target = os.path.join(BASE_DIR, "static", rel_path)

        # Check fallback in root directory for custom user files
        if not (os.path.exists(target) and os.path.isfile(target)):
            filename = os.path.basename(path)
            root_target = os.path.join(BASE_DIR, filename)
            if os.path.exists(root_target) and os.path.isfile(root_target):
                target = root_target

        if os.path.exists(target) and os.path.isfile(target):
            self.serve_file(target)
        else:
            # SPA Fallback to index.html for UI routes
            fallback = os.path.join(BASE_DIR, "static", "index.html")
            if os.path.exists(fallback):
                self.serve_file(fallback)
            else:
                self.send_error(404, "File Not Found")

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length).decode("utf-8") if content_length > 0 else "{}"
        try:
            body_json = json.loads(post_data)
        except Exception:
            body_json = {}

        # 1. Report Issue
        if path == "/api/report-issue":
            issue_text = body_json.get("issue", "Belirtilmedi")
            error_type = body_json.get("error_type")
            
            # Auto-infer error_type if not provided
            if not error_type:
                text_lower = issue_text.lower()
                if "algıla" in text_lower:
                    error_type = "error_1"
                elif "sınıflandı" in text_lower:
                    error_type = "error_2"
                elif "ayrıştı" in text_lower:
                    error_type = "error_3"
                else:
                    error_type = "error_4"

            # 1. Save locally for backup/offline logs
            report = save_reported_issue(issue_text, error_type=error_type)

            # 2. Update Supabase 'bin_errors' table (Upsert / Atomic increment)
            bin_id = body_json.get("bin_id") or CONFIG["BIN_ID"]
            supabase_result = report_bin_error_to_supabase(bin_id, error_type=error_type)

            resp = {
                "success": True,
                "message": "Sorun bildiriminiz başarıyla iletildi. Teşekkür ederiz.",
                "report": report,
                "supabase": supabase_result
            }
            res_bytes = json.dumps(resp, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(res_bytes)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(res_bytes)
            return

        # 2. Start Classification Flow (Camera motion settles -> AI analysis starts)
        if path == "/api/classify/start":
            event_payload = {
                "state": "CLASSIFYING",
                "timestamp": datetime.datetime.now().isoformat()
            }
            broadcaster.broadcast("classification_started", event_payload)
            resp = {"status": "started", "message": "Classification loading screen active"}
            res_bytes = json.dumps(resp).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(res_bytes)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(res_bytes)
            return

        # 3. Complete Classification Flow (AI result returned)
        if path == "/api/classify/result":
            waste_type = body_json.get("waste_type", "Plastik")
            confidence = float(body_json.get("confidence", 0.96))
            image_filename = body_json.get("image_filename", "sample_plastic_1.png")
            cooldown_duration = float(body_json.get("cooldown_duration", 5.0))
            is_unknown = (waste_type.upper() == "UNKNOWN" or waste_type.upper() == "BILINMIYOR" or body_json.get("state") == "FAILED")

            if not is_unknown and image_filename:
                add_waste_record(waste_type, confidence, image_filename)

            result_payload = {
                "state": "FAILED" if is_unknown else "COMPLETED",
                "waste_type": "Bilinmiyor" if is_unknown else waste_type,
                "confidence": confidence,
                "cooldown_duration": cooldown_duration,
                "image_url": f"/data/waste_images/{image_filename}" if image_filename else "/data/waste_images/sample_plastic_1.png",
                "timestamp": datetime.datetime.now().isoformat()
            }
            broadcaster.broadcast("classification_result", result_payload)

            resp = {"status": "completed", "result": result_payload}
            res_bytes = json.dumps(resp).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(res_bytes)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(res_bytes)
            return

        # 4. System Ready / Tray Cleared Event
        if path == "/api/system/ready":
            broadcaster.broadcast("system_ready", {"status": "ready", "timestamp": datetime.datetime.now().isoformat()})
            resp = {"status": "ready", "message": "System ready for next item"}
            res_bytes = json.dumps(resp).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(res_bytes)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(res_bytes)
            return

        # 4. Trigger Classification (Simulation with delay)
        if path == "/api/classify/trigger":
            waste_type = body_json.get("waste_type", "Plastik")
            confidence = float(body_json.get("confidence", 0.95))
            image_filename = body_json.get("image_filename", "sample_plastic_1.png")

            # If classification is UNKNOWN / failed
            is_unknown = (waste_type.upper() == "UNKNOWN" or waste_type.upper() == "BILINMIYOR")

            if not is_unknown:
                # Add to local gallery
                add_waste_record(waste_type, confidence, image_filename)

            # Broadcast SSE event to touch screen UI
            event_payload = {
                "state": "CLASSIFYING",
                "timestamp": datetime.datetime.now().isoformat()
            }
            broadcaster.broadcast("classification_started", event_payload)

            # Simulate 1.8s processing delay if requested
            cooldown_duration = float(body_json.get("cooldown_duration", 5.0))
            def finish_classification():
                time.sleep(1.8)
                result_payload = {
                    "state": "FAILED" if is_unknown else "COMPLETED",
                    "waste_type": "Bilinmiyor" if is_unknown else waste_type,
                    "confidence": confidence,
                    "cooldown_duration": cooldown_duration,
                    "image_url": f"/data/waste_images/{image_filename}",
                    "timestamp": datetime.datetime.now().isoformat()
                }
                broadcaster.broadcast("classification_result", result_payload)

            t = threading.Thread(target=finish_classification, daemon=True)
            t.start()

            resp = {"status": "started", "target": waste_type}
            res_bytes = json.dumps(resp).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(res_bytes)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(res_bytes)
            return

        # 3. Exit Kiosk / Application
        if path == "/api/exit":
            resp = {"success": True, "message": "Arayüz kapatılıyor..."}
            res_bytes = json.dumps(resp, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(res_bytes)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(res_bytes)

            def do_shutdown():
                time.sleep(0.3)
                sensor_reader.stop()
                # Forcefully terminate detector, presentation scripts, and browsers
                os.system("pkill -9 -f 'headless_hailo.py|headless_groq.py|gui_hailo.py|start_presentation.sh|chromium|chromium-browser|firefox' 2>/dev/null")
                time.sleep(0.3)
                os._exit(0)

            t = threading.Thread(target=do_shutdown, daemon=True)
            t.start()
            return

        self.send_error(404, "Endpoint Not Found")

    def serve_file(self, filepath):
        """Serves a static file with proper MIME type."""
        mime_type, _ = mimetypes.guess_type(filepath)
        if not mime_type:
            if filepath.endswith(".js"):
                mime_type = "application/javascript"
            elif filepath.endswith(".css"):
                mime_type = "text/css"
            elif filepath.endswith(".svg"):
                mime_type = "image/svg+xml"
            elif filepath.endswith(".json"):
                mime_type = "application/json"
            else:
                mime_type = "application/octet-stream"

        try:
            with open(filepath, "rb") as f:
                content = f.read()

            self.send_response(200)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-cache")
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_error(500, f"Error reading file: {e}")

# ---------------------------------------------------------------------------
# Main Server Runner
# ---------------------------------------------------------------------------
def run_server():
    host = CONFIG.get("HOST", "0.0.0.0")
    port = int(CONFIG.get("PORT", 8080))
    sensor_reader.start()
    server = ThreadedHTTPServer((host, port), KioskHTTPRequestHandler)
    print(f"=====================================================")
    print(f"  REBIN Touch Display Kiosk Server Running")
    print(f"  URL: http://localhost:{port}")
    print(f"  Target Resolution: 1280x720 Landscape")
    print(f"  Bin ID: {CONFIG['BIN_ID']}")
    print(f"  Occupancy Sensor: {CONFIG.get('OCCUPANCY_SENSOR_PORT', '/dev/ttyUSB0')}")
    print(f"=====================================================")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server gracefully...")
        sensor_reader.stop()
        server.server_close()

if __name__ == "__main__":
    run_server()

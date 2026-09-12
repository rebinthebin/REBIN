from __future__ import annotations
import os
import sys
import time
import numpy as np

ort = None  # Lazy-loaded inside create_session() to prevent unnecessary device discovery warnings

try:
    import serial  # type: ignore
except ImportError:
    serial = None

# Constants
CLASS_NAMES = {0: "glass", 1: "metal", 2: "paper", 3: "plastic"}
CLASS_COLORS_BGR = {          # for OpenCV drawing
    "glass":   (255, 200,   0),
    "metal":   (200, 200, 200),
    "paper":   (  0, 200, 255),
    "plastic": (  0, 100, 255),
}

try:
    from picamera2 import Picamera2  # type: ignore
except ImportError:
    # Fallback/mock for environments where picamera2 is not installed
    Picamera2 = None



def create_session(model_path: str):
    """
    Creates and returns an ONNX Runtime InferenceSession configured for CPU-only execution on Raspberry Pi 5.
    If the FP16 model fails to load, attempts fallback conversion to FP32.
    """
    global ort
    if ort is None:
        import onnxruntime as ort

    sess_options = ort.SessionOptions()
    sess_options.intra_op_num_threads = 4
    sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    sess_options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    
    providers = ['CPUExecutionProvider']
    
    try:
        # Try loading FP16 model
        session = ort.InferenceSession(model_path, sess_options, providers=providers)
        # Try warm up
        input_name = session.get_inputs()[0].name
        input_type = session.get_inputs()[0].type
        dtype = np.float16 if 'float16' in input_type else np.float32
        dummy_input = np.zeros((1, 3, 640, 640), dtype=dtype)
        session.run(None, {input_name: dummy_input})
        return session
    except Exception as e:
        print(f"Warning: FP16 model loading or warm-up failed on CPU: {e}", file=sys.stderr)
        print("Attempting fallback conversion of FP16 model to FP32...", file=sys.stderr)
        
        converted_path = model_path.replace(".onnx", "_fp32.onnx")
        if not os.path.exists(converted_path):
            try:
                import onnx
                from onnx import numpy_helper, TensorProto
                print(f"Loading {model_path} via ONNX for FP32 conversion...", file=sys.stderr)
                model = onnx.load(model_path)
                
                # Update inputs
                for input_tensor in model.graph.input:
                    if input_tensor.type.tensor_type.elem_type == TensorProto.FLOAT16:
                        input_tensor.type.tensor_type.elem_type = TensorProto.FLOAT
                        
                # Update outputs
                for output_tensor in model.graph.output:
                    if output_tensor.type.tensor_type.elem_type == TensorProto.FLOAT16:
                        output_tensor.type.tensor_type.elem_type = TensorProto.FLOAT
                        
                # Update value_info
                for value_info in model.graph.value_info:
                    if value_info.type.tensor_type.elem_type == TensorProto.FLOAT16:
                        value_info.type.tensor_type.elem_type = TensorProto.FLOAT
                        
                # Update initializers
                new_initializers = []
                for init in model.graph.initializer:
                    if init.data_type == TensorProto.FLOAT16:
                        array = numpy_helper.to_array(init)
                        array_f32 = array.astype('float32')
                        new_init = numpy_helper.from_array(array_f32, name=init.name)
                        new_initializers.append(new_init)
                    else:
                        new_initializers.append(init)
                del model.graph.initializer[:]
                model.graph.initializer.extend(new_initializers)
                
                # Update nodes
                for node in model.graph.node:
                    if node.op_type == "Cast":
                        for attr in node.attribute:
                            if attr.name == "to" and attr.i == TensorProto.FLOAT16:
                                attr.i = TensorProto.FLOAT
                    elif node.op_type == "Constant":
                        for attr in node.attribute:
                            if attr.name == "value" and attr.t.data_type == TensorProto.FLOAT16:
                                array = numpy_helper.to_array(attr.t)
                                array_f32 = array.astype('float32')
                                new_t = numpy_helper.from_array(array_f32, name=attr.t.name)
                                attr.t.CopyFrom(new_t)
                                
                onnx.save(model, converted_path)
                print(f"Successfully converted model saved to {converted_path}", file=sys.stderr)
            except ImportError:
                print("Error: The 'onnx' library is required to perform FP16 -> FP32 fallback conversion.", file=sys.stderr)
                print("Please run: pip3 install --break-system-packages onnx", file=sys.stderr)
                raise e
            except Exception as conv_err:
                print(f"Failed to convert model to FP32: {conv_err}", file=sys.stderr)
                raise e
        
        # Load the converted FP32 model
        try:
            session = ort.InferenceSession(converted_path, sess_options, providers=providers)
            input_name = session.get_inputs()[0].name
            dummy_input = np.zeros((1, 3, 640, 640), dtype=np.float32)
            session.run(None, {input_name: dummy_input})
            print("Successfully loaded converted FP32 model session.", file=sys.stderr)
            return session
        except Exception as e32:
            print(f"Failed to load converted FP32 model: {e32}", file=sys.stderr)
            raise e32


def create_cameras(single_rgb_only: bool = False, use_noir_only: bool = False) -> tuple:
    """
    Initializes camera 0 (RGB) and camera 1 (NoIR) using Picamera2.
    Queries sensor_modes to find the mode with the maximum area (widest FOV)
    and configures the main output stream to match its aspect ratio, applying a
    ScalerCrop to slightly decrease FOV (especially for the NoIR camera).
    """
    if Picamera2 is None:
        print("ERROR: picamera2 library is not available in this Python environment.", file=sys.stderr)
        print("Please check that it is installed or run 'libcamera-hello --list-cameras'.", file=sys.stderr)
        raise RuntimeError("picamera2 library not found")
        
    cams = []
    if use_noir_only:
        # Check if camera index 1 exists (in dual-camera setup, camera 1 was NoIR).
        # If camera 1 does not exist, fall back to camera 0 (single NIR camera connected).
        target_idx = 1
        try:
            test_cam = Picamera2(camera_num=1)
            test_cam.close()
        except Exception:
            target_idx = 0
        cam_indices = (target_idx,)
    elif single_rgb_only:
        cam_indices = (0,)
    else:
        cam_indices = (0, 1)
    for cam_idx in cam_indices:
        try:
            cam = Picamera2(camera_num=cam_idx)
            
            # Query sensor modes to find the mode with the maximum area (widest FOV)
            modes = cam.sensor_modes
            max_mode = None
            max_area = 0
            for mode in modes:
                # Try to get size safely from mode object/dict
                if hasattr(mode, "size"):
                    sz = mode.size
                elif isinstance(mode, dict) and "size" in mode:
                    sz = mode["size"]
                elif hasattr(mode, "get"):
                    sz = mode.get("size")
                else:
                    sz = getattr(mode, "size", None)
                
                if sz:
                    area = sz[0] * sz[1]
                    if area > max_area:
                        max_area = area
                        max_mode = mode
            
            # Determine the aspect ratio of the max FOV mode
            aspect_ratio = 4.0 / 3.0
            if max_mode:
                sz = getattr(max_mode, "size", None) or max_mode.get("size")
                if sz:
                    aspect_ratio = sz[0] / sz[1]
                    
            # Select main stream size to match the aspect ratio within a 640x640 box
            if aspect_ratio >= 1.0:
                main_w = 640
                main_h = int(640 / aspect_ratio)
            else:
                main_h = 640
                main_w = int(640 * aspect_ratio)
                
            # Make sure dimensions are even for compatibility
            main_w = (main_w // 2) * 2
            main_h = (main_h // 2) * 2
            main_size = (main_w, main_h)

            # Setup controls with FrameDurationLimits
            controls_dict = {"FrameDurationLimits": (33333, 33333)}
            
            if max_mode and sz:
                print(f"Configuring Camera {cam_idx} with aspect ratio {aspect_ratio:.3f} -> output size {main_size}, raw size {sz}", file=sys.stderr)
                config = cam.create_preview_configuration(
                    main={"format": "RGB888", "size": main_size},
                    raw={"size": sz},
                    controls=controls_dict
                )
            else:
                print(f"Configuring Camera {cam_idx} with aspect ratio {aspect_ratio:.3f} -> output size {main_size}", file=sys.stderr)
                config = cam.create_preview_configuration(
                    main={"format": "RGB888", "size": main_size},
                    controls=controls_dict
                )
            cam.configure(config)

            # Determine zoom factor to decrease FOV (zoom in)
            # Camera 0 (RGB) FOV is slightly decreased (zoom factor 1.20)
            # NoIR / NIR camera FOV is decreased even more (zoom factor 2.10)
            zoom_factor = 2.10 if (use_noir_only or cam_idx == 1) else 1.20
            
            # Apply ScalerCrop relative to the active sensor mode crop bounds
            if hasattr(cam, "camera_controls") and "ScalerCrop" in cam.camera_controls:
                try:
                    max_crop = cam.camera_controls["ScalerCrop"][1]
                    if max_crop and len(max_crop) >= 4:
                        w_crop = int(max_crop[2] / zoom_factor)
                        h_crop = int(max_crop[3] / zoom_factor)
                        # Ensure dimensions are even for compatibility
                        w_crop = (w_crop // 2) * 2
                        h_crop = (h_crop // 2) * 2
                        # Center the cropped region within the active sensor mode bounds
                        x_off = max_crop[0] + (max_crop[2] - w_crop) // 2
                        y_off = max_crop[1] + (max_crop[3] - h_crop) // 2
                        crop_rect = (x_off, y_off, w_crop, h_crop)
                        
                        cam.set_controls({"ScalerCrop": crop_rect})
                        print(f"Camera {cam_idx} FOV reduced (zoom={zoom_factor}x) -> ScalerCrop: {crop_rect} (bounds: {max_crop})", file=sys.stderr)
                except Exception as crop_err:
                    print(f"Warning: Failed to set ScalerCrop on camera {cam_idx}: {crop_err}", file=sys.stderr)
            
            cam.start()
            cams.append(cam)
        except Exception as e:
            print(f"ERROR: Camera (camera_num={cam_idx}) could not be initialized. Detailed error: {e}", file=sys.stderr)
            print("Please suggest checking: libcamera-hello --list-cameras", file=sys.stderr)
            # Stop any successfully started cameras before raising
            for c in cams:
                try:
                    c.stop()
                except Exception:
                    pass
            raise RuntimeError(f"Failed to initialize camera {cam_idx}") from e
            
    if use_noir_only:
        return cams[0], None
    if single_rgb_only:
        return cams[0], None
    return cams[0], cams[1]


def preprocess(frame_rgb: np.ndarray) -> np.ndarray:
    """
    Preprocesses frame_rgb from uint8 shape (640, 640, 3) to np.float16 shape (1, 3, 640, 640).
    """
    frame = frame_rgb.astype(np.float32) / 255.0  # normalize to [0,1]
    frame = np.transpose(frame, (2, 0, 1))         # HWC -> CHW
    frame = np.expand_dims(frame, 0)               # add batch dim -> [1,3,640,640]
    return frame.astype(np.float16)                # cast to FP16


def run_inference(session: ort.InferenceSession, input_tensor: np.ndarray) -> np.ndarray:
    """
    Runs model inference with session and input_tensor. Handles FP16 / FP32 conversion dynamically.
    """
    input_name = session.get_inputs()[0].name
    input_type = session.get_inputs()[0].type
    if 'float16' in input_type:
        feed_tensor = input_tensor.astype(np.float16)
    else:
        feed_tensor = input_tensor.astype(np.float32)
        
    raw_output = session.run(None, {input_name: feed_tensor})[0]
    return raw_output


def postprocess(raw_output: np.ndarray, conf_threshold: float = 0.50) -> list[dict]:
    """
    Decodes YOLOv10 end-to-end model output and filters detections below confidence threshold.
    Filters out bounding boxes that are too large (likely false positive background detections).
    """
    dets = raw_output[0].astype(np.float32)  # shape (300, 6)
    mask = dets[:, 4] >= conf_threshold
    dets = dets[mask]
    
    results = []
    for det in dets:
        class_id = int(det[5])
        class_name = CLASS_NAMES.get(class_id, f"unknown_{class_id}")
        x1, y1, x2, y2 = int(det[0]), int(det[1]), int(det[2]), int(det[3])
        
        # Filter out bounding boxes that cover almost the entire active frame
        # (e.g. width >= 600 and height >= 400), which are false positive background detections.
        box_w = x2 - x1
        box_h = y2 - y1
        if box_w >= 600 and box_h >= 400:
            continue
            
        results.append({
            "class_id": class_id,
            "class_name": class_name,
            "confidence": float(det[4]),
            "bbox": {
                "x1": x1,
                "y1": y1,
                "x2": x2,
                "y2": y2
            }
        })
    # Sort by confidence descending
    results.sort(key=lambda x: x["confidence"], reverse=True)
    return results


def capture_and_infer(
    cam: Picamera2,
    session: ort.InferenceSession,
    conf_threshold: float = 0.50
) -> tuple[np.ndarray, list[dict], float]:
    """
    Captures one frame, pads it to 640x640 (preserving aspect ratio/FOV), runs inference, and returns (frame_rgb, detections, inference_ms).
    """
    frame_raw_bgr = cam.capture_array()
    # Picamera2 capture_array returns BGR. Convert to RGB to match spec and model expectations.
    frame_raw = frame_raw_bgr[..., ::-1].copy()
    
    # Pad to 640x640 with letterbox padding to preserve aspect ratio and FOV without distortion
    h, w, c = frame_raw.shape
    if h != 640 or w != 640:
        frame_rgb = np.zeros((640, 640, 3), dtype=np.uint8)
        dy = (640 - h) // 2
        dx = (640 - w) // 2
        frame_rgb[dy:dy+h, dx:dx+w] = frame_raw
    else:
        frame_rgb = frame_raw
        
    input_tensor = preprocess(frame_rgb)
    
    t0 = time.perf_counter()
    raw_output = run_inference(session, input_tensor)
    t1 = time.perf_counter()
    
    inference_ms = (t1 - t0) * 1000.0
    detections = postprocess(raw_output, conf_threshold)
    
    return frame_rgb, detections, inference_ms


class UARTManager:
    """
    Manages USB UART connection to ESP32 and implements the detection state machine:
    - 2-second stabilization (continuous detection of the same class) before sending.
    - 10-second cooldown after sending.
    - After cooldown, requires the camera to become empty (no detections) before a new object is accepted.
    - Command characters: glass -> 'C', metal -> 'M', plastic -> 'P', paper -> 'K'.
    - Line endings: '\r\n'.
    """
    def __init__(self, port: str = "/dev/ttyACM0", baudrate: int = 115200, enabled: bool = True):
        self.port = port
        self.baudrate = baudrate
        self.enabled = enabled
        self.ser = None
        
        # State machine variables
        self.state = "IDLE"  # IDLE, STABILIZING, COOLDOWN
        self.stabilize_start_time = 0.0
        self.target_class = None
        self.cooldown_start_time = 0.0
        self.has_become_empty_since_send = False
        
        if self.enabled:
            if serial is None:
                print("Warning: 'pyserial' library is not installed in this environment.", file=sys.stderr)
                print("Please install it or run setup.sh first.", file=sys.stderr)
                print("Running in ESP32-less mode (detections will not be sent).", file=sys.stderr)
            else:
                self.connect()

    def connect(self):
        # List of candidate ports to try for motors
        ports_to_try = [self.port]
        
        # Fallback to other ACM ports if default fails
        if self.port == "/dev/ttyACM0":
            for fallback in ("/dev/ttyACM1", "/dev/ttyUSB1"):
                if os.path.exists(fallback) and fallback not in ports_to_try:
                    ports_to_try.append(fallback)
                    
        for p in ports_to_try:
            try:
                self.ser = serial.Serial(
                    port=p,
                    baudrate=self.baudrate,
                    timeout=1.0,
                    write_timeout=1.0
                )
                self.port = p  # Update to the successfully opened port
                print(f"UART connection established on {p} at {self.baudrate} baud.", file=sys.stderr)
                return
            except Exception:
                continue
                
        # If all candidates fail
        print(f"Warning: Failed to open UART port (tried {', '.join(ports_to_try)}).", file=sys.stderr)
        print("Running in ESP32-less mode (detections will not be sent).", file=sys.stderr)
        self.ser = None

    def close(self):
        if self.ser and self.ser.is_open:
            try:
                self.ser.close()
                print("UART connection closed.", file=sys.stderr)
            except Exception:
                pass

    @property
    def is_connected(self) -> bool:
        return self.ser is not None and getattr(self.ser, "is_open", False)

    def send_command(self, class_name: str):
        command_char = {
            "glass": "C",
            "metal": "M",
            "plastic": "P",
            "paper": "K"
        }.get(class_name)
        
        if not command_char:
            return
            
        msg = f"{command_char}\r\n"
        
        # If not currently connected, try auto-connecting (in case ESP32 was plugged in after launch)
        if not self.is_connected and self.enabled and serial is not None:
            self.connect()

        if self.is_connected:
            try:
                self.ser.write(msg.encode('utf-8'))
                self.ser.flush()
                print(f"UART: Sent '{command_char}' for class '{class_name}' to ESP32", file=sys.stderr)
            except Exception as e:
                print(f"Error sending UART data: {e}", file=sys.stderr)
                try:
                    self.ser.close()
                except Exception:
                    pass
                self.ser = None
        else:
            print(f"UART (Standalone): Command '{command_char}' generated for '{class_name}' (no ESP32 connected)", file=sys.stderr)

    def update(self, best_class: str):
        """
        Updates the state machine based on the highest confidence class in the current frame.
        """
        now = time.time()
        
        if self.state == "IDLE":
            if best_class is not None:
                self.state = "STABILIZING"
                self.stabilize_start_time = now
                self.target_class = best_class
                print(f"UART: Detection started for '{best_class}'. Waiting for 2s stabilization...", file=sys.stderr)
                
        elif self.state == "STABILIZING":
            if best_class is None:
                self.state = "IDLE"
                self.target_class = None
                print("UART: Object lost. Resetting to IDLE state.", file=sys.stderr)
            elif best_class != self.target_class:
                # Class changed, reset stabilization timer for the new class
                self.stabilize_start_time = now
                self.target_class = best_class
                print(f"UART: Class changed to '{best_class}'. Resetting 2s stabilization timer...", file=sys.stderr)
            else:
                # Same class continues
                elapsed = now - self.stabilize_start_time
                if elapsed >= 2.0:
                    self.send_command(self.target_class)
                    self.state = "COOLDOWN"
                    self.cooldown_start_time = now
                    self.has_become_empty_since_send = False
                    print(f"UART: Sent command. Entering 10s cooldown state...", file=sys.stderr)
                    
        elif self.state == "COOLDOWN":
            if best_class is None:
                if not self.has_become_empty_since_send:
                    self.has_become_empty_since_send = True
                    print("UART: Camera became empty (reset condition met).", file=sys.stderr)
                
            cooldown_elapsed = now - self.cooldown_start_time
            if cooldown_elapsed >= 10.0:
                if self.has_become_empty_since_send:
                    if best_class is not None:
                        self.state = "STABILIZING"
                        self.stabilize_start_time = now
                        self.target_class = best_class
                        print(f"UART: Cooldown finished. New detection '{best_class}' started. Waiting for 2s stabilization...", file=sys.stderr)
                    else:
                        self.state = "IDLE"
                        self.target_class = None
                        print("UART: Cooldown finished. System is IDLE.", file=sys.stderr)

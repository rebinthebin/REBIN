import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'tflite_service_interface.dart';
import 'dart:math';
import 'dart:async';

// Web için sahte (mock) TFLite servisi (Web'de TFLite FFI derlenemediği için)
class TFLiteServiceWeb implements TFLiteService {
  static Future<TFLiteService> create() async {
    return TFLiteServiceWeb();
  }

  @override
  Future<List<Map<String, dynamic>>> runInference(CameraImage cameraImage) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final Random rnd = Random();
    final materials = ['Plastik', 'Cam', 'Kağıt', 'Metal', 'Organik'];
    
    if (rnd.nextDouble() < 0.3) {
      return [];
    }
    
    final selectedMaterial = materials[rnd.nextInt(materials.length)];
    
    return [
      {
        'box': [0.2, 0.2, 0.8, 0.8],
        'label': selectedMaterial,
        'confidence': 0.85 + rnd.nextDouble() * 0.14,
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> runInferenceFromBytes(Uint8List imageBytes) async {
    return runInference(CameraImage.fromPlatformData({}));
  }

  @override
  List<String> get labels => ['plastic', 'glass', 'paper', 'metal'];

  @override
  Future<void> loadModel(String modelPath, {String? labelsPath}) async {
    // Web mock servisinde yapılacak bir şey yok
  }

  @override
  void close() {
    // Yapılacak bir şey yok
  }
}

// Bu metot stub dosyasıyla eşleşmesi için gerekli
Future<TFLiteService> createTFLiteService([String modelPath = 'assets/models/best_rebin_float16.tflite']) => TFLiteServiceWeb.create();

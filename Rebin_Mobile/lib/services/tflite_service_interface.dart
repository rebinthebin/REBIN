import 'dart:typed_data';
import 'package:camera/camera.dart';

// Tüm platformlarda geçerli ortak arayüz
abstract class TFLiteService {
  Future<List<Map<String, dynamic>>> runInference(CameraImage cameraImage);
  Future<List<Map<String, dynamic>>> runInferenceFromBytes(Uint8List imageBytes);
  Future<void> loadModel(String modelPath, {String? labelsPath});
  List<String> get labels;
  void close();
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:pytorch_lite/pigeon.dart';

class PyTorchService {
  ModelObjectDetection? _objectModel;
  bool _isLoaded = false;

  Future<void> loadModel({String modelPath = 'assets/models/best.torchscript', String labelsPath = 'assets/models/labels.txt'}) async {
    try {
      final rawLabels = await rootBundle.loadString(labelsPath);
      final labelsList = rawLabels.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final labelCount = labelsList.length;
      debugPrint('[PyTorch] Loading model: $modelPath with $labelCount classes: $labelsList');

      _objectModel = await PytorchLite.loadObjectDetectionModel(
        modelPath, 
        labelCount, 
        640, 
        640,
        labelPath: labelsPath,
        objectDetectionModelType: ObjectDetectionModelType.yolov8,
      );
      _isLoaded = true;
      debugPrint('[PyTorch] Model loaded successfully: $modelPath');
    } catch (e, stack) {
      debugPrint('[PyTorch] Error loading model: $e');
      debugPrint('[PyTorch] Load stack trace: $stack');
    }
  }

  Future<List<ResultObjectDetection>> runInference(Uint8List imageBytes) async {
    if (!_isLoaded || _objectModel == null) {
      debugPrint('[PyTorch] Inference requested but model not loaded.');
      return [];
    }
    try {
      debugPrint('[PyTorch] Starting inference, image bytes length: ${imageBytes.length}');
      final predictions = await _objectModel!.getImagePrediction(
        imageBytes,
        minimumScore: 0.15, // Temporarily lower threshold to see if anything is detected
        iOUThreshold: 0.40,
      );
      debugPrint('[PyTorch] Raw predictions count: ${predictions.length}');
      for (var i = 0; i < predictions.length; i++) {
        final p = predictions[i];
        if (p != null) {
          debugPrint('  Prediction $i: classIndex=${p.classIndex}, className=${p.className}, score=${p.score}');
        }
      }
      final filteredPredictions = predictions.whereType<ResultObjectDetection>().where((p) {
        // Alan hesaplaması: Eğer [0, 1] aralığında normalize ise width * height = alan yüzdesi (0.0 - 1.0)
        // Eğer mutlak değerdeyse width * height, (640*640)'a bölünerek alan hesaplanabilir.
        double area = p.rect.width * p.rect.height;
        if (p.rect.right > 1.0 || p.rect.bottom > 1.0) {
           area = area / (640.0 * 640.0);
        }
        return area <= 0.80; // %80'den büyükse arka plan olarak değerlendir ve yoksay
      }).toList();

      return filteredPredictions;
    } catch (e, stack) {
      debugPrint('[PyTorch] Inference error: $e');
      debugPrint('[PyTorch] Stack trace: $stack');
      return [];
    }
  }
}

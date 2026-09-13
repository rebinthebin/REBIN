import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:math';

import 'database_service.dart';
import 'tflite_service_interface.dart';

// ─────────────────────────────────────────────────────────
//  Sabitler
// ─────────────────────────────────────────────────────────
const double _kConfidenceThreshold = 0.35; // %35 altını yoksay
const double _kNmsIoUThreshold    = 0.40;
const double _kBackgroundRatio    = 0.90; // Ekranın %90'ını kaplayan bbox → gürültü

// ─────────────────────────────────────────────────────────
//  Model Mimari Tipleri
// ─────────────────────────────────────────────────────────
enum ModelArchitecture {
  /// YOLOv8/v11 raw çıktısı: [1, (4+numClasses), numAnchors]
  yoloRaw,
  /// NMS-built-in çıktısı (SSD/EfficientDet tarzı): [1, maxDetections, 6]
  /// Her detection: [y1, x1, y2, x2, score, classId]
  nmsBuiltIn,
}

// ─────────────────────────────────────────────────────────
//  Mobil TFLite Servisi
// ─────────────────────────────────────────────────────────
class TFLiteServiceMobile implements TFLiteService {
  late Interpreter   _interpreter;
  List<String>       _labels = [];
  late List<int>     _inputShape;
  late List<int>     _outputShape;
  late int           _inputSize; // 640 veya 128
  late TensorType    _inputType;
  ModelArchitecture  _architecture = ModelArchitecture.yoloRaw;
  final UserStaticsDatabase _dbService = UserStaticsDatabase.instance;

  @override
  List<String> get labels => _labels;

  static Future<TFLiteService> create([String modelPath = 'assets/models/best_rebin_float16.tflite']) async {
    final service = TFLiteServiceMobile();
    await service._loadModelFromPath(modelPath);
    // Model prefix'ine göre uygun label dosyasını belirle
    final labelsPath = _inferLabelsPath(modelPath);
    await service._loadLabels(labelsPath);
    return service;
  }

  /// Model yolundan uygun etiket dosyasını çıkarsayan yardımcı
  static String _inferLabelsPath(String modelPath) {
    // Tüm modeller aynı labels.txt kullanır (6 sınıf: cardboard, glass, metal, paper, plastic, trash)
    return 'assets/models/labels.txt';
  }

  // ── Model Yükleme ──────────────────────────────────────
  Future<void> _loadModelFromPath(String modelPath) async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: options,
      );
      _inputShape  = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(0).shape;
      _inputType   = _interpreter.getInputTensor(0).type;
      _inputSize   = _inputShape[1]; // 640 veya 128

      // ── Mimari Tipi Otomatik Tespiti ──────────────────
      // Output shape'e göre mimari tipi belirle:
      // - [1, N, 6] (N genellikle 300) → NMS-built-in
      // - [1, C, A] (C > 6) → YOLO raw
      if (_outputShape.length == 3) {
        final dim1 = _outputShape[1];
        final dim2 = _outputShape[2];

        if (dim2 == 6 && dim1 > 6) {
          // [1, 300, 6] formatı → NMS-built-in
          _architecture = ModelArchitecture.nmsBuiltIn;
        } else {
          // [1, 8, 8400] formatı → YOLO raw
          _architecture = ModelArchitecture.yoloRaw;
        }
      }

      debugPrint('[TFLite] Model yüklendi ($modelPath). '
          'Input: $_inputShape  Output: $_outputShape  '
          'Type: $_inputType  Mimari: $_architecture');
    } catch (e) {
      debugPrint('[TFLite] Model yükleme hatası: $e');
    }
  }

  // ── Dışarıdan Model Değiştirme ─────────────────────────
  @override
  Future<void> loadModel(String modelPath, {String? labelsPath}) async {
    try {
      _interpreter.close();
    } catch (_) {}
    await _loadModelFromPath(modelPath);

    // Etiketleri de güncelle
    final effectiveLabelsPath = labelsPath ?? _inferLabelsPath(modelPath);
    await _loadLabels(effectiveLabelsPath);

    debugPrint('[TFLite] Model değiştirildi: $modelPath (etiketler: $effectiveLabelsPath)');
  }

  // ── Etiketler ──────────────────────────────────────────
  Future<void> _loadLabels(String labelsPath) async {
    try {
      final raw  = await rootBundle.loadString(labelsPath);
      _labels    = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      debugPrint('[TFLite] Etiketler ($labelsPath): $_labels');
    } catch (e) {
      debugPrint('[TFLite] Etiket yükleme hatası ($labelsPath): $e');
      // Fallback
      _labels = ['plastic', 'glass', 'paper', 'metal'];
    }
  }

  // ── Ana Çıkarım ────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> runInference(CameraImage cameraImage) async {
    try {
      final input = _preprocessYUV420(cameraImage);
      if (input == null) return [];

      // Mimariye göre farklı çıkarım yolları
      switch (_architecture) {
        case ModelArchitecture.yoloRaw:
          return _runYoloRawInference(input, cameraImage);
        case ModelArchitecture.nmsBuiltIn:
          return _runNmsBuiltInInference(input, cameraImage);
      }
    } catch (e) {
      debugPrint('[TFLite] Çıkarım hatası: $e');
      return [];
    }
  }

  // ── JPEG Bytes'tan Çıkarım ─────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> runInferenceFromBytes(Uint8List imageBytes) async {
    try {
      final input = _preprocessJpegBytes(imageBytes);
      if (input == null) return [];

      switch (_architecture) {
        case ModelArchitecture.yoloRaw:
          return _runYoloRawInferenceFromInput(input);
        case ModelArchitecture.nmsBuiltIn:
          return _runNmsBuiltInInferenceFromInput(input);
      }
    } catch (e) {
      debugPrint('[TFLite] Bytes çıkarım hatası: $e');
      return [];
    }
  }

  // ── JPEG → Tensor Ön İşleme ────────────────────────────
  Uint8List? _preprocessJpegBytes(Uint8List jpegBytes) {
    try {
      img.Image? decoded = img.decodeImage(jpegBytes);
      if (decoded == null) return null;

      // inputSize'a yeniden boyutlandır (genellikle 640x640)
      if (decoded.width != _inputSize || decoded.height != _inputSize) {
        decoded = img.copyResize(decoded, width: _inputSize, height: _inputSize);
      }

      // RGB kanallarını çıkar
      if (decoded.numChannels != 3) {
        decoded = decoded.convert(format: img.Format.uint8, numChannels: 3);
      }

      final bool isFloat32 = _inputType == TensorType.float32;
      final bool isInt8 = _inputType == TensorType.int8;
      final int byteSize = isFloat32 ? 4 : 1;
      final Uint8List buffer = Uint8List(_inputSize * _inputSize * 3 * byteSize);
      final ByteData byteData = ByteData.view(buffer.buffer);

      final inputTensor = _interpreter.getInputTensor(0);
      final double quantScale = inputTensor.params.scale;
      final int quantZeroPoint = inputTensor.params.zeroPoint;

      int byteOffset = 0;
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixel = decoded.getPixel(x, y);
          final int r = pixel.r.toInt();
          final int g = pixel.g.toInt();
          final int b = pixel.b.toInt();

          if (isFloat32) {
            byteData.setFloat32(byteOffset, r / 255.0, Endian.little); byteOffset += 4;
            byteData.setFloat32(byteOffset, g / 255.0, Endian.little); byteOffset += 4;
            byteData.setFloat32(byteOffset, b / 255.0, Endian.little); byteOffset += 4;
          } else if (isInt8) {
            if (quantScale != 0.0) {
              byteData.setInt8(byteOffset++, ((r / 255.0) / quantScale + quantZeroPoint).round().clamp(-128, 127));
              byteData.setInt8(byteOffset++, ((g / 255.0) / quantScale + quantZeroPoint).round().clamp(-128, 127));
              byteData.setInt8(byteOffset++, ((b / 255.0) / quantScale + quantZeroPoint).round().clamp(-128, 127));
            } else {
              byteData.setInt8(byteOffset++, (r - 128).clamp(-128, 127));
              byteData.setInt8(byteOffset++, (g - 128).clamp(-128, 127));
              byteData.setInt8(byteOffset++, (b - 128).clamp(-128, 127));
            }
          } else {
            // uint8
            byteData.setUint8(byteOffset++, r);
            byteData.setUint8(byteOffset++, g);
            byteData.setUint8(byteOffset++, b);
          }
        }
      }
      return buffer;
    } catch (e) {
      debugPrint('[TFLite] JPEG ön işleme hatası: $e');
      return null;
    }
  }

  // ── Input-based inference (CameraImage bağımsız) ───────
  List<Map<String, dynamic>> _runYoloRawInferenceFromInput(Uint8List input) {
    final int numChannels = _outputShape[1];
    final int numAnchors  = _outputShape[2];

    final outputTensor = _interpreter.getOutputTensor(0);
    final TensorType outputType = outputTensor.type;
    final bool isOutputFloat32 = outputType == TensorType.float32;

    final dynamic outputBuffer;
    if (isOutputFloat32) {
      outputBuffer = [
        List.generate(numChannels, (_) => List<double>.filled(numAnchors, 0.0))
      ];
    } else {
      outputBuffer = [
        List.generate(numChannels, (_) => List<int>.filled(numAnchors, 0))
      ];
    }

    _interpreter.run(input, outputBuffer);

    final double outScale = outputTensor.params.scale;
    final int outZeroPoint = outputTensor.params.zeroPoint;

    final rawRows = (outputBuffer[0] as List).map((row) =>
        (row as List).map((v) {
          final double doubleVal = (v as num).toDouble();
          if (!isOutputFloat32 && outScale != 0.0) {
            return (doubleVal - outZeroPoint) * outScale;
          }
          return doubleVal;
        }).toList(),
    ).toList();

    return _processYOLOv8Output(rawRows, _inputSize.toDouble(), _inputSize.toDouble());
  }

  List<Map<String, dynamic>> _runNmsBuiltInInferenceFromInput(Uint8List input) {
    final int maxDetections = _outputShape[1];
    final int detColumns    = _outputShape[2];

    final outputBuffer = [
      List.generate(maxDetections, (_) => List<double>.filled(detColumns, 0.0))
    ];

    _interpreter.run(input, outputBuffer);

    return _processNmsBuiltInOutput(outputBuffer[0], _inputSize.toDouble(), _inputSize.toDouble());
  }

  // ── YOLO Raw Çıkarım (rebin modelleri) ────────────────
  List<Map<String, dynamic>> _runYoloRawInference(
    Uint8List input,
    CameraImage cameraImage,
  ) {
    // YOLOv8/v11 çıktısı: [1, (4+numClasses), 8400]
    final int numChannels  = _outputShape[1];
    final int numAnchors   = _outputShape[2];

    final outputTensor = _interpreter.getOutputTensor(0);
    final TensorType outputType = outputTensor.type;
    final bool isOutputFloat32 = outputType == TensorType.float32;

    final dynamic outputBuffer;
    if (isOutputFloat32) {
      outputBuffer = [
        List.generate(numChannels, (_) => List<double>.filled(numAnchors, 0.0))
      ];
    } else {
      outputBuffer = [
        List.generate(numChannels, (_) => List<int>.filled(numAnchors, 0))
      ];
    }

    _interpreter.run(input, outputBuffer);

    final double outScale = outputTensor.params.scale;
    final int outZeroPoint = outputTensor.params.zeroPoint;

    // outputBuffer[0] is List<List> — convert safely without casting
    final rawRows = (outputBuffer[0] as List).map((row) =>
        (row as List).map((v) {
          final double doubleVal = (v as num).toDouble();
          if (!isOutputFloat32 && outScale != 0.0) {
            return (doubleVal - outZeroPoint) * outScale;
          }
          return doubleVal;
        }).toList(),
    ).toList();

    final results = _processYOLOv8Output(
      rawRows,
      cameraImage.width.toDouble(),
      cameraImage.height.toDouble(),
    );

    return results;
  }

  // ── NMS-Built-In Çıkarım (best modelleri) ─────────────
  List<Map<String, dynamic>> _runNmsBuiltInInference(
    Uint8List input,
    CameraImage cameraImage,
  ) {
    // Çıktı: [1, maxDetections, 6]
    // Her detection: [y1, x1, y2, x2, score, classId]
    final int maxDetections = _outputShape[1];
    final int detColumns    = _outputShape[2]; // 6

    final outputBuffer = [
      List.generate(maxDetections, (_) => List<double>.filled(detColumns, 0.0))
    ];

    _interpreter.run(input, outputBuffer);

    return _processNmsBuiltInOutput(
      outputBuffer[0],
      cameraImage.width.toDouble(),
      cameraImage.height.toDouble(),
    );
  }

  // ── YUV420 → RGB Float32/Int8/Uint8 Dönüşümü ───────────
  // Android kamera akışı genellikle YUV_420_888 formatında gelir.
  // planes[0] = Y, planes[1] = U, planes[2] = V
  Uint8List? _preprocessYUV420(CameraImage image) {
    try {
      final int width  = image.width;
      final int height = image.height;

      final yPlane  = image.planes[0];
      final uPlane  = image.planes[1];
      final vPlane  = image.planes[2];

      final Uint8List yBytes = yPlane.bytes;
      final Uint8List uBytes = uPlane.bytes;
      final Uint8List vBytes = vPlane.bytes;

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      final bool isFloat32 = _inputType == TensorType.float32;
      final bool isInt8 = _inputType == TensorType.int8;
      final bool isUint8 = _inputType == TensorType.uint8;

      final int byteSize = isFloat32 ? 4 : 1;
      final Uint8List buffer = Uint8List(_inputSize * _inputSize * 3 * byteSize);
      final ByteData byteData = ByteData.view(buffer.buffer);

      // Örnekleme adımı (basit nearest-neighbor küçültme)
      final double scaleX = width / _inputSize;
      final double scaleY = height / _inputSize;

      int byteOffset = 0;

      final inputTensor = _interpreter.getInputTensor(0);
      final double quantScale = inputTensor.params.scale;
      final int quantZeroPoint = inputTensor.params.zeroPoint;

      for (int outY = 0; outY < _inputSize; outY++) {
        for (int outX = 0; outX < _inputSize; outX++) {
          final int srcX = (outX * scaleX).toInt().clamp(0, width - 1);
          final int srcY = (outY * scaleY).toInt().clamp(0, height - 1);

          final int yIdx = srcY * yRowStride + srcX;
          final int uvIdx =
              (srcY ~/ 2) * uvRowStride + (srcX ~/ 2) * uvPixelStride;

          final int yVal = yBytes[yIdx] & 0xFF;
          final int uVal = (uvIdx < uBytes.length ? uBytes[uvIdx] : 128) & 0xFF;
          final int vVal = (uvIdx < vBytes.length ? vBytes[uvIdx] : 128) & 0xFF;

          // YUV → RGB dönüşümü (BT.601)
          final double y = yVal.toDouble();
          final double u = uVal.toDouble() - 128.0;
          final double v = vVal.toDouble() - 128.0;

          final double r = (y + 1.402 * v).clamp(0, 255);
          final double g = (y - 0.344136 * u - 0.714136 * v).clamp(0, 255);
          final double b = (y + 1.772 * u).clamp(0, 255);

          if (isFloat32) {
            byteData.setFloat32(byteOffset, r / 255.0, Endian.little);
            byteOffset += 4;
            byteData.setFloat32(byteOffset, g / 255.0, Endian.little);
            byteOffset += 4;
            byteData.setFloat32(byteOffset, b / 255.0, Endian.little);
            byteOffset += 4;
          } else if (isUint8) {
            byteData.setUint8(byteOffset++, r.round());
            byteData.setUint8(byteOffset++, g.round());
            byteData.setUint8(byteOffset++, b.round());
          } else if (isInt8) {
            if (quantScale != 0.0) {
              byteData.setInt8(byteOffset++, ((r / 255.0) / quantScale + quantZeroPoint).round().clamp(-128, 127));
              byteData.setInt8(byteOffset++, ((g / 255.0) / quantScale + quantZeroPoint).round().clamp(-128, 127));
              byteData.setInt8(byteOffset++, ((b / 255.0) / quantScale + quantZeroPoint).round().clamp(-128, 127));
            } else {
              byteData.setInt8(byteOffset++, (r - 128.0).round().clamp(-128, 127));
              byteData.setInt8(byteOffset++, (g - 128.0).round().clamp(-128, 127));
              byteData.setInt8(byteOffset++, (b - 128.0).round().clamp(-128, 127));
            }
          }
        }
      }
      return buffer;
    } catch (e) {
      debugPrint('[TFLite] Görüntü ön işleme hatası: $e');
      return null;
    }
  }

  // ── YOLOv8/v11 Çıktı İşleme ──────────────────────────
  // Çıktı: [numChannels, numAnchors] — transpoze edilmemiş hali
  // numChannels = 4 (bbox) + numClasses
  List<Map<String, dynamic>> _processYOLOv8Output(
    List<List<double>> rawOutput,
    double imgWidth,
    double imgHeight,
  ) {
    final int numAnchors = rawOutput[0].length;
    final int numClasses = rawOutput.length - 4;

    final List<double>       scores   = [];
    final List<List<double>> boxes    = [];
    final List<int>          classIds = [];

    for (int a = 0; a < numAnchors; a++) {
      // Kutu koordinatları (normalize edilmiş, model giriş boyutuna göre)
      final double cx = rawOutput[0][a];
      final double cy = rawOutput[1][a];
      final double bw = rawOutput[2][a];
      final double bh = rawOutput[3][a];

      // En iyi sınıf
      double maxScore   = 0.0;
      int    bestClass  = -1;
      for (int c = 0; c < numClasses; c++) {
        final double s = rawOutput[4 + c][a];
        if (s > maxScore) { maxScore = s; bestClass = c; }
      }

      if (maxScore < _kConfidenceThreshold) continue;
      if (bestClass < 0 || bestClass >= _labels.length) continue;

      // Koordinatları 0-1 normalize aralığına çevir (model inputSize baz alınmış)
      final double xmin = ((cx - bw / 2) / _inputSize).clamp(0.0, 1.0);
      final double ymin = ((cy - bh / 2) / _inputSize).clamp(0.0, 1.0);
      final double xmax = ((cx + bw / 2) / _inputSize).clamp(0.0, 1.0);
      final double ymax = ((cy + bh / 2) / _inputSize).clamp(0.0, 1.0);

      // ── Arka Plan Gürültüsü Filtresi ──────────────────
      // Bbox genişliği orijinal görüntünün %90'ından büyükse yoksay
      final double normalizedWidth = xmax - xmin;
      if (normalizedWidth > _kBackgroundRatio) continue;

      scores.add(maxScore);
      boxes.add([xmin, ymin, xmax, ymax]);
      classIds.add(bestClass);
    }

    // NMS uygula
    final selectedIdx = _nms(boxes, scores, _kNmsIoUThreshold);

    return selectedIdx.map((i) => {
      'box'       : boxes[i],
      'label'     : _labels[classIds[i]],
      'confidence': scores[i],
      'classId'   : classIds[i],
    }).toList();
  }

  // ── NMS-Built-In Çıktı İşleme (best modelleri) ───────
  // Çıktı: [maxDetections][6]
  // Her detection: [y1, x1, y2, x2, score, classId]
  // Koordinatlar zaten normalize (0-1 aralığında)
  // NMS zaten model içinde uygulanmış
  List<Map<String, dynamic>> _processNmsBuiltInOutput(
    List<List<double>> rawOutput,
    double imgWidth,
    double imgHeight,
  ) {
    final List<Map<String, dynamic>> results = [];

    for (final det in rawOutput) {
      final double score = det[4];

      // Düşük güvenli tespitleri atla
      if (score < _kConfidenceThreshold) continue;

      final int classId = det[5].round().clamp(0, _labels.length - 1);

      // Koordinatları [y1, x1, y2, x2] → [xmin, ymin, xmax, ymax] olarak dönüştür
      final double y1 = det[0].clamp(0.0, 1.0);
      final double x1 = det[1].clamp(0.0, 1.0);
      final double y2 = det[2].clamp(0.0, 1.0);
      final double x2 = det[3].clamp(0.0, 1.0);

      // ── Arka Plan Gürültüsü Filtresi ──────────────────
      final double normalizedWidth = (x2 - x1).abs();
      if (normalizedWidth > _kBackgroundRatio) continue;

      results.add({
        'box'       : [x1, y1, x2, y2], // [xmin, ymin, xmax, ymax]
        'label'     : _labels[classId],
        'confidence': score,
        'classId'   : classId,
      });
    }

    return results;
  }

  // ── Non-Maximum Suppression ────────────────────────────
  List<int> _nms(
    List<List<double>> boxes,
    List<double> scores,
    double iouThreshold,
  ) {
    final indices = List.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));

    final selected    = <int>[];
    final suppressed  = List<bool>.filled(scores.length, false);

    for (int i = 0; i < indices.length; i++) {
      final idx = indices[i];
      if (suppressed[idx]) continue;
      selected.add(idx);
      for (int j = i + 1; j < indices.length; j++) {
        final next = indices[j];
        if (suppressed[next]) continue;
        if (_iou(boxes[idx], boxes[next]) >= iouThreshold) {
          suppressed[next] = true;
        }
      }
    }
    return selected;
  }

  double _iou(List<double> a, List<double> b) {
    final xA = max(a[0], b[0]);
    final yA = max(a[1], b[1]);
    final xB = min(a[2], b[2]);
    final yB = min(a[3], b[3]);
    final inter = max(0.0, xB - xA) * max(0.0, yB - yA);
    final aArea = (a[2] - a[0]) * (a[3] - a[1]);
    final bArea = (b[2] - b[0]) * (b[3] - b[1]);
    return inter / (aArea + bArea - inter + 1e-6);
  }

  @override
  void close() {
    _interpreter.close();
    _dbService.close();
  }
}

// Bu metot stub dosyasıyla eşleşmesi için gerekli
Future<TFLiteService> createTFLiteService([String modelPath = 'assets/models/best_rebin_float16.tflite']) => TFLiteServiceMobile.create(modelPath);

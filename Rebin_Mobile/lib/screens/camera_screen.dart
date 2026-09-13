import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import '../services/pytorch_service.dart';
import '../services/tflite_service.dart';
import 'result_screen.dart';
import 'package:pytorch_lite/pigeon.dart';
import '../core/waste_theme.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  PyTorchService? _pytorchService;
  TFLiteService? _tfliteService;
  bool _isProcessing = false;
  List<String> _availableModels = [];
  String _currentModel = 'assets/models/best_full_integer_quant.tflite';
  bool _isTFLiteActive = true; // Şu an TFLite mi, PyTorch mu kullanılıyor?

  // Aktif mod değişkenleri
  bool _isActiveMode = false;
  bool _isProcessingFrame = false;
  ResultObjectDetection? _bestLiveDetection;

  // Animasyon Kontrolcüleri
  late AnimationController _flashController;
  late Animation<Color?> _flashAnimation;

  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    
    // Yeşil parlama animasyonu
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _flashAnimation = ColorTween(
      begin: Colors.white38,
      end: Colors.green,
    ).animate(CurvedAnimation(parent: _flashController, curve: Curves.elasticOut));

    // Dönen geri dönüşüm logosu animasyonu
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initApp();
  }

  Future<void> _initApp() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final requestStatus = await Permission.camera.request();
      if (!requestStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kamera izni gereklidir.')),
          );
          context.pop();
        }
        return;
      }
    }

    try {
      final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> assets = assetManifest.listAssets();
      
      _availableModels = assets
          .where((key) => key.startsWith('assets/models/') && !key.endsWith('.txt'))
          .map((key) => key.split('/').last)
          .toList();

      if (_availableModels.contains('best_full_integer_quant.tflite')) {
        _availableModels.remove('best_full_integer_quant.tflite');
        _availableModels.insert(0, 'best_full_integer_quant.tflite');
      }
    } catch (e) {
      debugPrint("AssetManifest yüklenemedi: $e");
      _availableModels = ['best_int8.tflite', 'best_float16.tflite', 'best.torchscript', 'best.pt'];
    }

    _pytorchService = PyTorchService();

    if (_currentModel.endsWith('.tflite')) {
      _tfliteService ??= await TFLiteServiceWrapper.create(_currentModel);
      if (_tfliteService != null) {
        await _tfliteService!.loadModel(_currentModel);
      }
      _isTFLiteActive = true;
    } else {
      await _pytorchService!.loadModel(modelPath: _currentModel);
      _isTFLiteActive = false;
    }
    
    await _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uygun kamera bulunamadı.')),
        );
      }
      return;
    }

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint("Kamera başlatma hatası: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _flashController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _showModelSelectionDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          title: Row(
            children: [
              const Icon(Icons.settings, color: Colors.green),
              const SizedBox(width: 8),
              Text('Kamera Ayarları', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ],
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateSB) {
              return Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ..._availableModels.map((modelName) => _buildModelOption(modelName, dialogContext)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Aktif Mod', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            subtitle: Text('Sürekli canlı görüntü işleme', style: GoogleFonts.outfit(fontSize: 12)),
                            activeColor: Colors.green,
                            value: _isActiveMode,
                            onChanged: (val) {
                              setStateSB(() { _isActiveMode = val; });
                              _toggleActiveMode(val);
                            },
                          ),
                        ),
                    ),
                  ],
                ),
              );
            }
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Kapat', style: GoogleFonts.outfit(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _toggleActiveMode(bool isActive) async {
    setState(() {
      _isActiveMode = isActive;
      _bestLiveDetection = null;
    });
    
    if (isActive) {
      if (_controller != null && !_controller!.value.isStreamingImages) {
        await _controller!.startImageStream(_processLiveFrame);
      }
    } else {
      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
    }
  }

  void _processLiveFrame(CameraImage image) async {
    if (!_isActiveMode || _isProcessingFrame || !mounted) return;
    _isProcessingFrame = true;

    try {
      final screenSize = MediaQuery.of(context).size;
      final planes = image.planes.map((p) => p.bytes).toList();
      final width = image.width;
      final height = image.height;
      final formatStr = image.format.group == ImageFormatGroup.yuv420 ? 'yuv420' : 
                       (image.format.group == ImageFormatGroup.bgra8888 ? 'bgra8888' : 'jpeg');
      
      final Map<String, dynamic> data = {
        'planes': planes,
        'width': width,
        'height': height,
        'format': formatStr,
        'strides': image.planes.map((p) => p.bytesPerRow).toList(),
        'pixelStrides': image.planes.map((p) => p.bytesPerPixel).toList(),
        'screenWidth': screenSize.width,
        'screenHeight': screenSize.height,
      };

      final Uint8List? processedBytes = await compute(_convertLiveFrame, data);

      if (processedBytes != null && _isActiveMode && mounted) {
        List<ResultObjectDetection> preds;
        if (_isTFLiteActive && _tfliteService != null) {
            final tfliteResults = await _tfliteService!.runInferenceFromBytes(processedBytes);
            preds = tfliteResults.map((m) {
              final box = m['box'] as List;
              return ResultObjectDetection(
                classIndex: (m['classId'] as int?) ?? 0,
                className: m['label'] as String? ?? 'Bilinmiyor',
                score: (m['confidence'] as num?)?.toDouble() ?? 0.0,
                rect: PyTorchRect(
                  left: (box[0] as num).toDouble(),
                  top: (box[1] as num).toDouble(),
                  right: (box[2] as num).toDouble(),
                  bottom: (box[3] as num).toDouble(),
                  width: (box[2] as num).toDouble() - (box[0] as num).toDouble(),
                  height: (box[3] as num).toDouble() - (box[1] as num).toDouble(),
                ),
              );
            }).toList();
        } else {
            preds = await _pytorchService!.runInference(processedBytes);
        }
        
        if (preds.isNotEmpty && _isActiveMode && mounted) {
            ResultObjectDetection? frameBest;
            for (var p in preds) {
              if (frameBest == null || p.score > frameBest.score) {
                frameBest = p;
              }
            }
            
            if (frameBest != null) {
              setState(() {
                if (_bestLiveDetection == null || frameBest!.score > _bestLiveDetection!.score) {
                  _bestLiveDetection = frameBest;
                }
              });
            }
        }
      }
    } catch (e) {
      debugPrint("Live frame error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _isProcessingFrame = false;
    }
  }

  static Uint8List? _convertLiveFrame(Map<String, dynamic> data) {
    try {
      final List<Uint8List> planes = data['planes'];
      final int width = data['width'];
      final int height = data['height'];
      final String format = data['format'];
      final double screenWidth = data['screenWidth'];
      final double screenHeight = data['screenHeight'];

      img.Image? decodedImage;

      if (format == 'jpeg') {
        decodedImage = img.decodeImage(planes[0]);
      } else if (format == 'bgra8888') {
        decodedImage = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: planes[0].buffer,
          order: img.ChannelOrder.bgra,
        );
      } else if (format == 'yuv420') {
        final int uvRowStride = data['strides'][1];
        final int uvPixelStride = data['pixelStrides'][1] ?? 2; 
        
        decodedImage = img.Image(width: width, height: height, numChannels: 3, format: img.Format.uint8);
        for (int y = 0; y < height; y++) {
          int pY = y * width;
          int pUV = (y ~/ 2) * uvRowStride;
          for (int x = 0; x < width; x++) {
            int uvOffset = pUV + (x ~/ 2) * uvPixelStride;
            // Güvenlik kontrolü
            if (pY >= planes[0].length || uvOffset >= planes[1].length || uvOffset >= planes[2].length) break;

            int yVal = planes[0][pY] & 0xFF;
            int uVal = planes[1][uvOffset] & 0xFF;
            int vVal = planes[2][uvOffset] & 0xFF;
            
            int c = yVal - 16;
            int d = uVal - 128;
            int e = vVal - 128;
            
            int r = (298 * c + 409 * e + 128) >> 8;
            int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
            int b = (298 * c + 516 * d + 128) >> 8;
            
            decodedImage.setPixelRgb(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
            pY++;
          }
        }
      }

      if (decodedImage == null) return null;

      if (width > height) {
        decodedImage = img.copyRotate(decodedImage, angle: 90);
      }

      if (decodedImage.numChannels != 3) {
        decodedImage = decodedImage.convert(format: img.Format.uint8, numChannels: 3);
      }

      final int imageWidth = decodedImage.width;
      final int imageHeight = decodedImage.height;

      final double ringSize = screenWidth * 0.85;

      final double scale = math.max(screenWidth / imageWidth, screenHeight / imageHeight);
      final double scaledWidth = imageWidth * scale;
      final double scaledHeight = imageHeight * scale;

      final double screenOffsetX = (scaledWidth - screenWidth) / 2;
      final double screenOffsetY = (scaledHeight - screenHeight) / 2;

      final double ringX = (screenWidth - ringSize) / 2;
      final double ringY = (screenHeight - ringSize) / 2;

      final double scaledRingX = screenOffsetX + ringX;
      final double scaledRingY = screenOffsetY + ringY;

      int cropX = (scaledRingX / scale).toInt();
      int cropY = (scaledRingY / scale).toInt();
      int cropSize = (ringSize / scale).toInt();

      cropX = math.max(0, cropX);
      cropY = math.max(0, cropY);
      cropSize = math.min(cropSize, math.min(imageWidth - cropX, imageHeight - cropY));

      img.Image cropped = img.copyCrop(decodedImage, x: cropX, y: cropY, width: cropSize, height: cropSize);
      img.Image resized = img.copyResize(cropped, width: 640, height: 640);

      return Uint8List.fromList(img.encodeJpg(resized));
    } catch (e) {
      debugPrint("Live frame conversion error: $e");
      return null;
    }
  }

  static Uint8List? _cropAndResizeImage(Map<String, dynamic> data) {
    try {
      final Uint8List imageBytes = data['bytes'];
      final double screenWidth = data['screenWidth'];
      final double screenHeight = data['screenHeight'];

      img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return null;

      if (decodedImage.width > decodedImage.height) {
        decodedImage = img.copyRotate(decodedImage, angle: 90);
      }

      if (decodedImage.numChannels != 3) {
        decodedImage = decodedImage.convert(format: img.Format.uint8, numChannels: 3);
      }

      final int imageWidth = decodedImage.width;
      final int imageHeight = decodedImage.height;

      final double ringSize = screenWidth * 0.85;

      final double scale = math.max(screenWidth / imageWidth, screenHeight / imageHeight);
      final double scaledWidth = imageWidth * scale;
      final double scaledHeight = imageHeight * scale;

      final double screenOffsetX = (scaledWidth - screenWidth) / 2;
      final double screenOffsetY = (scaledHeight - screenHeight) / 2;

      final double ringX = (screenWidth - ringSize) / 2;
      final double ringY = (screenHeight - ringSize) / 2;

      final double scaledRingX = screenOffsetX + ringX;
      final double scaledRingY = screenOffsetY + ringY;

      int cropX = (scaledRingX / scale).toInt();
      int cropY = (scaledRingY / scale).toInt();
      int cropSize = (ringSize / scale).toInt();

      cropX = math.max(0, cropX);
      cropY = math.max(0, cropY);
      cropSize = math.min(cropSize, math.min(imageWidth - cropX, imageHeight - cropY));

      img.Image cropped = img.copyCrop(decodedImage, x: cropX, y: cropY, width: cropSize, height: cropSize);
      img.Image resized = img.copyResize(cropped, width: 640, height: 640);

      return Uint8List.fromList(img.encodeJpg(resized));
  } catch (e) {
    debugPrint("Crop error: $e");
    return null;
  }
}

  static List<Uint8List> _generateAugmentations(Uint8List imageBytes) {
    try {
      img.Image? decoded = img.decodeImage(imageBytes);
      if (decoded == null) return [imageBytes];

      List<Uint8List> results = [imageBytes];

      // 1. Yatay Çevirme (Flipped)
      img.Image flipped = img.flipHorizontal(decoded.clone());
      results.add(Uint8List.fromList(img.encodeJpg(flipped)));

      // 2. Zoom (%10 yakınlaştırma)
      int zoomCropSize = (640 * 0.9).toInt();
      int offset = (640 - zoomCropSize) ~/ 2;
      img.Image zoomedCrop = img.copyCrop(decoded, x: offset, y: offset, width: zoomCropSize, height: zoomCropSize);
      img.Image zoomed = img.copyResize(zoomedCrop, width: 640, height: 640);
      results.add(Uint8List.fromList(img.encodeJpg(zoomed)));

      // 3. Hafif Rotasyon (15 derece)
      img.Image rotated = img.copyRotate(decoded.clone(), angle: 15);
      // Rotasyon siyah kenarlıklar oluşturabilir, 640x640 merkezden tekrar kırpalım
      int rotOffset = (rotated.width - 640) ~/ 2;
      if (rotOffset > 0) {
        rotated = img.copyCrop(rotated, x: rotOffset, y: rotOffset, width: 640, height: 640);
      }
      results.add(Uint8List.fromList(img.encodeJpg(rotated)));

      // 4. Parlaklık Artırma (+%20)
      img.Image brightened = img.adjustColor(decoded.clone(), amount: 1.2);
      results.add(Uint8List.fromList(img.encodeJpg(brightened)));

      return results;
    } catch (e) {
      debugPrint("Augmentation error: $e");
      return [imageBytes];
    }
  }

  Widget _buildModelOption(String modelName, BuildContext dialogContext) {
    final String fullPath = 'assets/models/$modelName';
    final bool isSelected = _currentModel == fullPath;
    final bool isSpecial = modelName == 'best_full_integer_quant.tflite';
    final String displayName = isSpecial ? 'REBIN_yolo11n' : modelName;
    final Color color = isSpecial ? Colors.green : (isSelected ? Colors.green : Colors.grey);

    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: color,
      ),
      title: Text(
        displayName,
        style: GoogleFonts.outfit(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
      onTap: () {
        Navigator.pop(dialogContext);
        if (_currentModel != fullPath) {
          _changeModel(fullPath);
        }
      },
    );
  }

  Future<void> _changeModel(String modelPath) async {
    setState(() => _isProcessing = true);
    final isTFLite = modelPath.endsWith('.tflite');
    if (isTFLite) {
      _tfliteService ??= await TFLiteServiceWrapper.create(modelPath);
      await _tfliteService!.loadModel(modelPath);
      _isTFLiteActive = true;
    } else {
      await _pytorchService!.loadModel(modelPath: modelPath);
      _isTFLiteActive = false;
    }
    setState(() {
      _currentModel = modelPath;
      _isProcessing = false;
    });
  }

  Future<void> _onCapture() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    _flashController.duration = const Duration(seconds: 1);
    _flashController.forward().then((_) {
      _flashController.reverse().then((_) {
        _flashController.forward().then((_) {
          _flashController.reverse();
        });
      });
    });

    try {
      final XFile file = await _controller!.takePicture();
      final Uint8List rawBytes = await file.readAsBytes();

      final screenSize = MediaQuery.of(context).size;
      final Map<String, dynamic> data = {
        'bytes': rawBytes,
        'screenWidth': screenSize.width,
        'screenHeight': screenSize.height,
      };
      final Uint8List? croppedBytes = await compute(_cropAndResizeImage, data);

      if (croppedBytes == null) {
        throw Exception("Görüntü işlenemedi.");
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/captured_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(croppedBytes);

      try {
        await _controller!.pausePreview();
      } catch (e) {
        debugPrint("Preview duraklatılamadı: $e");
      }

      // 6. Inference (TTA Uygulaması - 5 varyasyon)
      final augmentations = await compute(_generateAugmentations, croppedBytes);
      
      List<ResultObjectDetection> originalPreds = [];
      ResultObjectDetection? bestOverallDetection;

      // 5 kare arasında dolaş ve mutlak en yüksek skoru/türü bul
      for (int i = 0; i < augmentations.length; i++) {
        List<ResultObjectDetection> preds;

        if (_isTFLiteActive && _tfliteService != null) {
          // TFLite inference — Map çıktısını ResultObjectDetection'a dönüştür
          final tfliteResults = await _tfliteService!.runInferenceFromBytes(augmentations[i]);
          preds = tfliteResults.map((m) {
            final box = m['box'] as List;
            final label = m['label'] as String? ?? 'Bilinmiyor';
            final conf = (m['confidence'] as num?)?.toDouble() ?? 0.0;
            final classId = (m['classId'] as int?) ?? 0;
            return ResultObjectDetection(
              classIndex: classId,
              className: label,
              score: conf,
              rect: PyTorchRect(
                left: (box[0] as num).toDouble(),
                top: (box[1] as num).toDouble(),
                right: (box[2] as num).toDouble(),
                bottom: (box[3] as num).toDouble(),
                width: (box[2] as num).toDouble() - (box[0] as num).toDouble(),
                height: (box[3] as num).toDouble() - (box[1] as num).toDouble(),
              ),
            );
          }).toList();
        } else {
          // PyTorch inference
          preds = await _pytorchService!.runInference(augmentations[i]);
        }

        if (i == 0) originalPreds = preds;

        for (var p in preds) {
          if (bestOverallDetection == null || p.score > bestOverallDetection.score) {
            bestOverallDetection = p;
          }
        }
      }

      List<ResultObjectDetection> finalPredictions = [];
      if (bestOverallDetection != null) {
        // En yüksek skoru alan tahminin Sınıfını bulduk.
        // Şimdi görsel tutarlılık için Orijinal resimde AYNI SINIF için bir kutu var mı diye bakalım:
        ResultObjectDetection? boxToUse;
        for (var p in originalPreds) {
           if (p.className == bestOverallDetection.className) {
              if (boxToUse == null || p.score > boxToUse.score) {
                 boxToUse = p;
              }
           }
        }
        
        // Eğer orijinal resimde o sınıf yoksa ama başka bir şey bulduysa,
        // Orijinal resimdeki HERHANGİ bir kutuyu (varsa) yedek olarak kullan.
        if (boxToUse == null && originalPreds.isNotEmpty) {
           boxToUse = originalPreds.first;
        }

        // Eğer orijinalde hiçbir şey yoksa mecburen en iyiyi (augmented) kullan.
        boxToUse ??= bestOverallDetection;

        // Sonuç: En iyi tespit edilen sınıf/skor, ama orijinal resme uygun kutu!
        final syntheticPred = ResultObjectDetection(
          classIndex: boxToUse.classIndex,
          className: bestOverallDetection.className,
          score: bestOverallDetection.score,
          rect: boxToUse.rect,
        );
        finalPredictions.add(syntheticPred);
      }

      if (!mounted) return;

      // 7. Sonuç Ekranına Geçiş
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            imagePath: tempFile.path,
            detections: finalPredictions,
          ),
        ),
      );

      // Geri dönüldüğünde kamerayı devam ettir
      if (mounted) {
        try {
          await _controller!.resumePreview();
        } catch (e) {
          debugPrint("Preview devam ettirilemedi: $e");
        }
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint("Görüntü yakalama veya işleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görüntü işlenirken bir hata oluştu.')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Kamera yükleniyor...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Kamera Önizlemesi
          CameraPreview(_controller!),

          // Karartma (Eğer İşleniyorsa)
          if (_isProcessing)
            Container(
              color: Colors.black54,
            ),

          // 2. Üst Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Text(
                    'REBIN Tarayıcı',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white, size: 26),
                  onPressed: _isProcessing ? null : _showModelSelectionDialog,
                ),
              ],
            ),
          ),

          // 3. Odak Halkası (Merkez)
          Center(
            child: AnimatedBuilder(
              animation: _flashAnimation,
              builder: (context, child) {
                return Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _flashAnimation.value ?? Colors.white38,
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            ),
          ),

          // 4. Talimat veya Bekleme Yazısı / Logosu
          Center(
            child: _isProcessing
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: RotationTransition(
                          turns: _spinController,
                          child: const Icon(
                            Icons.recycling,
                            color: Colors.green,
                            size: 64,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Malzeme Sınıflandırılıyor',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : (_isActiveMode ? const SizedBox.shrink() : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.center_focus_weak,
                        color: Colors.white38,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Atığı çemberin içine getirin\nve fotoğraf çekin',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )),
          ),

          // 5. Fotoğraf Çekme Butonu VEYA Ana Bilgi Kutusu (Alt Orta)
          if (!_isProcessing)
            if (_isActiveMode)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_bestLiveDetection != null)
                      GestureDetector(
                        onTap: () {
                          if (_bestLiveDetection!.score >= 0.50 && !_isProcessing) {
                            _onCapture();
                          }
                        },
                        child: DetectionInfoBox(
                          label: _mapLabelToTurkish(_bestLiveDetection!.className ?? 'Bilinmiyor'),
                          confidence: _bestLiveDetection!.score,
                          color: _colorOf(_mapLabelToTurkish(_bestLiveDetection!.className ?? 'Bilinmiyor')),
                          isTrash: _mapLabelToTurkish(_bestLiveDetection!.className ?? 'Bilinmiyor') == 'Çöp',
                          isInteractive: _bestLiveDetection!.score >= 0.50,
                        ),
                      )
                    else
                      const DetectionInfoBox(
                        label: 'Bekleniyor...',
                        confidence: 0.0,
                        color: Colors.grey,
                        isInteractive: false,
                      ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        setState(() { _bestLiveDetection = null; });
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: Text(
                        'Taramayı Yenile',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _onCapture,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.6),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _mapLabelToTurkish(String label) {
    switch (label.toLowerCase()) {
      case 'plastic':
      case 'plastik':
        return 'Plastik';
      case 'glass':
      case 'cam':
        return 'Cam';
      case 'metal':
        return 'Metal';
      case 'paper':
      case 'cardboard':
      case 'kağıt':
      case 'kagit':
        return 'Kağıt';
      case 'trash':
      case 'çöp':
      case 'cop':
        return 'Çöp';
      default:
        return label;
    }
  }

  final Map<String, Color> _kClassColors = {
    'Plastik': WasteTheme.plasticColor,
    'Kağıt': WasteTheme.paperColor,
    'Cam': WasteTheme.glassColor,
    'Metal': WasteTheme.metalColor,
    'Çöp': WasteTheme.trashColor,
  };

  Color _colorOf(String label) => _kClassColors.entries
      .firstWhere(
        (e) => label.toLowerCase().contains(e.key.toLowerCase()),
        orElse: () => const MapEntry('', Colors.grey),
      )
      .value;
}

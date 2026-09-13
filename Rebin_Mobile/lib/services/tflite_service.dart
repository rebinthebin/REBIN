import 'tflite_service_interface.dart';
import 'tflite_service_mobile.dart' if (dart.library.html) 'tflite_service_web.dart';

// Koşullu içe aktarım (Conditional Import) ile platforma uygun servisi yaratır.

export 'tflite_service_interface.dart';

class TFLiteServiceWrapper {
  static Future<TFLiteService> create([String modelPath = 'assets/models/best_rebin_float16.tflite']) async {
    return await createTFLiteService(modelPath);
  }
}


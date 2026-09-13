import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect TFLite API', () async {
    print("--- START TENSOR TYPE INSPECTION ---");
    try {
      final file = File('assets/models/rebin_float16.tflite');
      if (!file.existsSync()) {
        print("File does not exist at: ${file.absolute.path}");
      }
      final interpreter = Interpreter.fromFile(file);
      final tensor = interpreter.getInputTensor(0);
      print("Tensor Name: ${tensor.name}");
      print("Tensor Type: ${tensor.type}");
      print("Tensor Shape: ${tensor.shape}");
      
      // Let's print the members of tensor using reflection or dynamic try-catch
      try {
        print("Tensor runtimeType: ${tensor.runtimeType}");
      } catch (_) {}

      interpreter.close();
    } catch (e) {
      print("Interpreter error: $e");
    }
    print("--- END TENSOR TYPE INSPECTION ---");
  });
}

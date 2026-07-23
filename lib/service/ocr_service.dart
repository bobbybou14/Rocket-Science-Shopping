import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static const String _windowsSampleReceiptPath = 'assets/sample_receipt.txt';

  static Future<String> extractTextFromImage(String imagePath) async {
    if (imagePath.trim().isEmpty) {
      throw const OcrException('A receipt image path is required.');
    }

    if (kIsWeb) {
      throw const OcrException(
        'Receipt OCR is not currently supported in the web version.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _extractWithMlKit(imagePath);

      case TargetPlatform.windows:
        return _loadWindowsDevelopmentReceipt();

      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw OcrException(
          'Receipt OCR is not currently supported on '
          '${defaultTargetPlatform.name}.',
        );
    }
  }

  static Future<String> _extractWithMlKit(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final recognizedText = await textRecognizer.processImage(inputImage);

      final extractedText = recognizedText.text.trim();

      if (extractedText.isEmpty) {
        throw const OcrException('No readable text was found on the receipt.');
      }

      return extractedText;
    } on OcrException {
      rethrow;
    } catch (error, stackTrace) {
      throw OcrException(
        'The receipt image could not be processed by ML Kit.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  static Future<String> _loadWindowsDevelopmentReceipt() async {
    try {
      final sampleText = await rootBundle.loadString(_windowsSampleReceiptPath);

      final cleanedText = sampleText.trim();

      if (cleanedText.isEmpty) {
        throw const OcrException('The Windows sample receipt file is empty.');
      }

      debugPrint(
        'Windows development mode: using '
        '$_windowsSampleReceiptPath instead of image OCR.',
      );

      return cleanedText;
    } on OcrException {
      rethrow;
    } catch (error, stackTrace) {
      throw OcrException(
        'Could not load the Windows sample receipt text. '
        'Confirm that assets/sample_receipt.txt exists and is '
        'listed in pubspec.yaml.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class OcrException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const OcrException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    if (cause == null) {
      return 'OcrException: $message';
    }

    return 'OcrException: $message Cause: $cause';
  }
}

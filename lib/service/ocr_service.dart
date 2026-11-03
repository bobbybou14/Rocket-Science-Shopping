import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'windows_ocr_service.dart';
import 'receipt_row_reconstruction_service.dart';

class OcrService {
  const OcrService._();

  static Future<String> extractTextFromImage(String imagePath) async {
    final cleanedPath = imagePath.trim();

    if (cleanedPath.isEmpty) {
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
        return _extractWithMlKit(cleanedPath);

      case TargetPlatform.windows:
        return _extractWithWindowsOcr(cleanedPath);

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
      final extractedText = _reconstructRows(recognizedText);

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

  static String _reconstructRows(RecognizedText recognizedText) {
    final fragments = recognizedText.blocks
        .expand((block) => block.lines)
        .where((line) => line.text.trim().isNotEmpty)
        .toList();
    final geometry = fragments.map((line) {
      final box = line.boundingBox;
      final corners = line.cornerPoints.length >= 4
          ? line.cornerPoints
                .take(4)
                .map(
                  (point) => math.Point<double>(
                    point.x.toDouble(),
                    point.y.toDouble(),
                  ),
                )
                .toList()
          : [
              math.Point<double>(box.left, box.top),
              math.Point<double>(box.right, box.top),
              math.Point<double>(box.right, box.bottom),
              math.Point<double>(box.left, box.bottom),
            ];
      return ReceiptOcrFragment(text: line.text, corners: corners);
    }).toList();
    final reconstructed = ReceiptRowReconstructionService.reconstruct(
      geometry,
      fallbackText: recognizedText.text,
    );
    if (kDebugMode) {
      debugPrint('----- RECONSTRUCTED RECEIPT ROWS START -----');
      final rows = reconstructed.split('\n');
      for (var index = 0; index < rows.length; index++) {
        debugPrint('RECEIPT ROW ${index + 1}: ${rows[index]}');
      }
      debugPrint('----- RECONSTRUCTED RECEIPT ROWS END -----');
    }
    return reconstructed;
  }

  static Future<String> _extractWithWindowsOcr(String imagePath) async {
    try {
      final extractedText = await WindowsOcrService.extractText(imagePath);

      if (kDebugMode) {
        debugPrint('Windows OCR extracted ${extractedText.length} characters.');
        debugPrint('----- RAW RECEIPT OCR START -----');

        final ocrLines = extractedText.split('\n');

        for (var index = 0; index < ocrLines.length; index++) {
          debugPrint('OCR LINE ${index + 1}: ${ocrLines[index]}');
        }

        debugPrint('----- RAW RECEIPT OCR END -----');
      }

      return extractedText;
    } on WindowsOcrException catch (error, stackTrace) {
      throw OcrException(
        error.message,
        cause: error.cause ?? error,
        stackTrace: error.stackTrace ?? stackTrace,
      );
    } catch (error, stackTrace) {
      throw OcrException(
        'The receipt image could not be processed by Windows OCR.',
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

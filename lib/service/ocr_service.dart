import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'windows_ocr_service.dart';

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

    if (fragments.isEmpty) {
      return recognizedText.text.trim();
    }

    double median(Iterable<double> values) {
      final sorted = values.toList()..sort();
      final middle = sorted.length ~/ 2;

      return sorted.length.isOdd
          ? sorted[middle]
          : (sorted[middle - 1] + sorted[middle]) / 2;
    }

    // Learn the reading direction from the detected text edges.
    // This supports rotated image coordinates as well as modest tilt.
    final directionX = <double>[];
    final directionY = <double>[];

    for (final line in fragments) {
      final points = line.cornerPoints;
      if (points.length < 4) continue;

      final dx = (points[1].x - points[0].x).toDouble();
      final dy = (points[1].y - points[0].y).toDouble();
      final length = math.sqrt(dx * dx + dy * dy);

      final sideX = (points[3].x - points[0].x).toDouble();
      final sideY = (points[3].y - points[0].y).toDouble();
      final height = math.sqrt(sideX * sideX + sideY * sideY);

      // Longer lines give a more reliable direction estimate.
      if (length <= 0 || length < height * 3) continue;

      directionX.add(dx / length);
      directionY.add(dy / length);
    }

    // Preserve the original text if orientation cannot be established.
    if (directionX.isEmpty) {
      return recognizedText.text.trim();
    }

    var alongX = median(directionX);
    var alongY = median(directionY);
    final magnitude = math.sqrt(alongX * alongX + alongY * alongY);

    if (magnitude < 0.5) {
      return recognizedText.text.trim();
    }

    alongX /= magnitude;
    alongY /= magnitude;

    // The perpendicular direction runs down the printed receipt.
    final downX = -alongY;
    final downY = alongX;

    double rowY(TextLine line) {
      final points = line.cornerPoints;

      if (points.length >= 4) {
        return points
                .map((point) => point.x * downX + point.y * downY)
                .reduce((first, second) => first + second) /
            points.length;
      }

      final center = line.boundingBox.center;
      return center.dx * downX + center.dy * downY;
    }

    double textHeight(TextLine line) {
      final points = line.cornerPoints;

      if (points.length >= 4) {
        final dx = points[3].x - points[0].x;
        final dy = points[3].y - points[0].y;
        final height = (dx * downX + dy * downY).abs();

        if (height > 0) return height;
      }

      final box = line.boundingBox;
      final height = box.width * downX.abs() + box.height * downY.abs();

      return height > 0 ? height : 1.0;
    }

    double leftEdge(TextLine line) {
      final points = line.cornerPoints;

      if (points.length >= 4) {
        return points
            .map((point) => point.x * alongX + point.y * alongY)
            .reduce((first, second) => first < second ? first : second);
      }

      final box = line.boundingBox;
      final center = box.center;
      final halfWidth =
          (box.width * alongX.abs() + box.height * alongY.abs()) / 2;

      return center.dx * alongX + center.dy * alongY - halfWidth;
    }

    double rightEdge(TextLine line) {
      final points = line.cornerPoints;

      if (points.length >= 4) {
        return points
            .map((point) => point.x * alongX + point.y * alongY)
            .reduce((first, second) => first > second ? first : second);
      }

      final box = line.boundingBox;
      final width = box.width * alongX.abs() + box.height * alongY.abs();

      return leftEdge(line) + width;
    }

    fragments.sort((first, second) {
      final comparison = rowY(first).compareTo(rowY(second));

      return comparison != 0
          ? comparison
          : leftEdge(first).compareTo(leftEdge(second));
    });

    final rows = <List<TextLine>>[];

    for (final fragment in fragments) {
      List<TextLine>? closestRow;
      var closestDistance = double.infinity;

      for (final row in rows) {
        final distance = (rowY(fragment) - median(row.map(rowY))).abs();

        final fragmentHeight = textHeight(fragment);
        final rowHeight = median(row.map(textHeight));
        final smallerHeight = fragmentHeight < rowHeight
            ? fragmentHeight
            : rowHeight;

        if (distance > smallerHeight * 0.55 || distance >= closestDistance) {
          continue;
        }

        final overlapsExistingText = row.any((existing) {
          final firstLeft = leftEdge(fragment);
          final firstRight = rightEdge(fragment);
          final secondLeft = leftEdge(existing);
          final secondRight = rightEdge(existing);

          final overlapLeft = firstLeft > secondLeft ? firstLeft : secondLeft;
          final overlapRight = firstRight < secondRight
              ? firstRight
              : secondRight;

          final firstWidth = firstRight - firstLeft;
          final secondWidth = secondRight - secondLeft;
          final smallerWidth = firstWidth < secondWidth
              ? firstWidth
              : secondWidth;

          return smallerWidth > 0 &&
              overlapRight - overlapLeft > smallerWidth * 0.2;
        });

        if (overlapsExistingText) continue;

        closestRow = row;
        closestDistance = distance;
      }

      if (closestRow == null) {
        rows.add([fragment]);
      } else {
        closestRow.add(fragment);
      }
    }

    rows.sort((first, second) {
      return median(first.map(rowY)).compareTo(median(second.map(rowY)));
    });

    final reconstructedLines = <String>[];

    for (final row in rows) {
      row.sort((first, second) {
        return leftEdge(first).compareTo(leftEdge(second));
      });

      reconstructedLines.add(row.map((line) => line.text.trim()).join(' '));
    }

    if (kDebugMode) {
      debugPrint('----- RECONSTRUCTED RECEIPT ROWS START -----');
      debugPrint('Reading direction: x=$alongX, y=$alongY');

      for (var index = 0; index < reconstructedLines.length; index++) {
        debugPrint('RECEIPT ROW ${index + 1}: ${reconstructedLines[index]}');
      }

      debugPrint('----- RECONSTRUCTED RECEIPT ROWS END -----');
    }

    return reconstructedLines.join('\n').trim();
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

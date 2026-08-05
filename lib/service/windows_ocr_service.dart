import 'dart:convert';
import 'dart:io';

class WindowsOcrService {
  const WindowsOcrService._();

  static const String _defaultTesseractPath =
      r'C:\Program Files\Tesseract-OCR\tesseract.exe';

  static Future<String> extractText(String imagePath) async {
    final cleanedPath = imagePath.trim();

    if (cleanedPath.isEmpty) {
      throw const WindowsOcrException('A receipt image path is required.');
    }

    final imageFile = File(cleanedPath);

    if (!await imageFile.exists()) {
      throw WindowsOcrException(
        'The selected receipt image could not be found: $cleanedPath',
      );
    }

    final tesseractFile = File(_defaultTesseractPath);

    if (!await tesseractFile.exists()) {
      throw const WindowsOcrException(
        'Tesseract was not found at '
        'C:\\Program Files\\Tesseract-OCR\\tesseract.exe.',
      );
    }

    try {
      final primaryText = await _runTesseract(
        imagePath: cleanedPath,
        pageSegmentationMode: '6',
      );

      var bestText = primaryText;
      var bestScore = _scoreResult(primaryText);

      final primaryLooksWeak =
          primaryText.length < 80 || _usableLineCount(primaryText) < 5;

      if (primaryLooksWeak) {
        final fallbackModes = ['4', '11'];

        for (final mode in fallbackModes) {
          final fallbackText = await _runTesseract(
            imagePath: cleanedPath,
            pageSegmentationMode: mode,
          );

          final fallbackScore = _scoreResult(fallbackText);

          if (fallbackScore > bestScore) {
            bestText = fallbackText;
            bestScore = fallbackScore;
          }
        }
      }

      if (bestText.trim().isEmpty) {
        throw const WindowsOcrException(
          'No readable text was found on the receipt.',
        );
      }

      return bestText.trim();
    } on WindowsOcrException {
      rethrow;
    } on ProcessException catch (error, stackTrace) {
      throw WindowsOcrException(
        'Tesseract could not be started.',
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw WindowsOcrException(
        'Windows could not extract text from the receipt image.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<String> _runTesseract({
    required String imagePath,
    required String pageSegmentationMode,
  }) async {
    final result = await Process.run(
      _defaultTesseractPath,
      [
        imagePath,
        'stdout',
        '-l',
        'eng',
        '--oem',
        '1',
        '--psm',
        pageSegmentationMode,
      ],
      runInShell: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    final extractedText = result.stdout.toString().trim();
    final errorText = result.stderr.toString().trim();

    if (result.exitCode != 0) {
      throw WindowsOcrException(
        errorText.isEmpty
            ? 'Tesseract exited with code ${result.exitCode}.'
            : 'Tesseract failed: $errorText',
      );
    }

    return extractedText;
  }

  static int _scoreResult(String value) {
    final lines = value
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final letterCount = RegExp(r'[A-Za-z]').allMatches(value).length;
    final digitCount = RegExp(r'[0-9]').allMatches(value).length;
    final priceCount = RegExp(r'\d+[.,]\d{2}').allMatches(value).length;

    return letterCount + digitCount + (lines.length * 15) + (priceCount * 30);
  }

  static int _usableLineCount(String value) {
    return value
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.length >= 3)
        .length;
  }
}

class WindowsOcrException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const WindowsOcrException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    if (cause == null) {
      return 'WindowsOcrException: $message';
    }

    return 'WindowsOcrException: $message Cause: $cause';
  }
}

import 'package:flutter/foundation.dart';

class OcrNormalizationService {
  const OcrNormalizationService._();

  static String normalize(String rawText) {
    if (rawText.trim().isEmpty) {
      return '';
    }

    final normalizedLines = <String>[];

    final lines = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u2028', '\n')
        .replaceAll('\u2029', '\n')
        .split('\n');

    for (final rawLine in lines) {
      final normalizedLine = _normalizeLine(rawLine);

      if (normalizedLine.isEmpty) {
        continue;
      }

      if (_isExternalArtifactLine(normalizedLine)) {
        continue;
      }

      normalizedLines.add(normalizedLine);
    }

    final normalizedText = normalizedLines.join('\n').trim();

    debugPrint(
      'OCR normalization produced '
      '${normalizedLines.length} usable lines.',
    );

    debugPrint('----- NORMALIZED RECEIPT OCR START -----');

    for (var index = 0; index < normalizedLines.length; index++) {
      debugPrint(
        'NORMALIZED LINE ${index + 1}: '
        '${normalizedLines[index]}',
      );
    }

    debugPrint('----- NORMALIZED RECEIPT OCR END -----');

    return normalizedText;
  }

  static String _normalizeLine(String line) {
    var normalized = line
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\uFEFF', '')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('−', '-')
        .replaceAll('‐', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    if (normalized.isEmpty) {
      return '';
    }

    // "$ 4.99" becomes "$4.99".
    normalized = normalized.replaceAllMapped(
      RegExp(r'\$\s+(\d)'),
      (match) => '\$${match.group(1)}',
    );

    // "4 . 99" becomes "4.99".
    normalized = normalized.replaceAllMapped(
      RegExp(r'(\d)\s*\.\s*(\d{2})\b'),
      (match) => '${match.group(1)}.${match.group(2)}',
    );

    // "25.00 -" becomes "25.00-".
    normalized = normalized.replaceAllMapped(
      RegExp(r'(\d+\.\d{2})\s+-\s*$'),
      (match) => '${match.group(1)}-',
    );

    // Normalize spacing around quantity separators.
    normalized = normalized
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)\s*([@Xx])\s*'),
          (match) => '${match.group(1)} ${match.group(2)!.toUpperCase()} ',
        )
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    normalized = _repairCommaDecimal(normalized);
    normalized = _repairCompactPriceAndTaxCode(normalized);
    normalized = _repairWalmartCompactPrice(normalized);
    normalized = _separateMergedLettersAndNumbers(normalized);
    normalized = _repairKnownMergedProductWords(normalized);

    return normalized.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  static String _repairCommaDecimal(String line) {
    // Examples:
    // "4, 00" -> "4.00"
    // "26-48" is deliberately not changed because the separator is not
    // clearly intended to be a decimal point.
    return line.replaceAllMapped(
      RegExp(r'\b(\d+)\s*,\s*(\d{2})\b'),
      (match) => '${match.group(1)}.${match.group(2)}',
    );
  }

  static String _repairCompactPriceAndTaxCode(String line) {
    // Costco-style OCR sometimes merges a three-digit price and its
    // trailing tax code:
    //
    // "679N" -> "6.79 N"
    // "899N" -> "8.99 N"
    //
    // Restrict this repair to a final token containing exactly three
    // price digits followed by a known receipt tax/status letter.
    return line.replaceAllMapped(
      RegExp(r'\b(\d)(\d{2})([NOXYJH])\b', caseSensitive: false),
      (match) {
        final dollars = match.group(1);
        final cents = match.group(2);
        final code = match.group(3)!.toUpperCase();

        return '$dollars.$cents $code';
      },
    );
  }

  static String _repairWalmartCompactPrice(String line) {
    // Confirmed Windows OCR pattern from Walmart:
    //
    // "GV 2 GAL 078742351870 F 27510"
    //
    // The printed text was:
    //
    // "GV 2 GAL 078742351870 F 2.75 O"
    //
    // Apply this only when the line has a Walmart-style UPC, an "F"
    // field, and a five-digit final token. The final two characters are
    // treated as OCR noise from the tax/status column.
    final match = RegExp(
      r'^(.*\b\d{11,14}\b\s+F\s+)(\d)(\d{2})(\d{2})(\s*.*)$',
      caseSensitive: false,
    ).firstMatch(line);

    if (match == null) {
      return line;
    }

    final prefix = match.group(1) ?? '';
    final dollars = match.group(2) ?? '';
    final cents = match.group(3) ?? '';
    final trailingText = match.group(5) ?? '';

    if (dollars.isEmpty || cents.length != 2) {
      return line;
    }

    return '$prefix$dollars.$cents$trailingText';
  }

  static String _separateMergedLettersAndNumbers(String line) {
    var normalized = line;

    // Product descriptions commonly contain packaging information that
    // Windows OCR joins to surrounding letters:
    //
    // "EGGS2.5DZ" -> "EGGS 2.5 DZ"
    // "454G" remains "454 G", which the parser can still understand.
    normalized = normalized.replaceAllMapped(
      RegExp(r'([A-Za-z])(\d+(?:\.\d+)?)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)([A-Za-z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return normalized;
  }

  static String _repairKnownMergedProductWords(String line) {
    var normalized = line;

    // Keep this list intentionally small. These are confirmed OCR merges
    // from actual tested receipts rather than speculative corrections.
    const replacements = <String, String>{'HOMOMILK': 'HOMO MILK'};

    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(
        RegExp(r'\b' + entry.key + r'\b', caseSensitive: false),
        entry.value,
      );
    }

    return normalized;
  }

  static bool _isExternalArtifactLine(String line) {
    final upper = line.toUpperCase();

    return upper.contains('ORDERS & PURCHASES') ||
        upper.contains('ORDERS AND PURCHASES') ||
        upper.contains('MY ACCOUNT | COSTCO') ||
        upper.contains('COSTCO.CA/MYACCOUNT') ||
        upper.contains('PRINTED FROM') ||
        upper.contains('DOWNLOAD RECEIPT') ||
        upper.contains('VIEW IN BROWSER') ||
        upper.contains('OPEN IN NEW TAB') ||
        upper.contains('PAGE 1 OF') ||
        upper.contains('PAGE 2 OF') ||
        upper.startsWith('HTTP://') ||
        upper.startsWith('HTTPS://') ||
        upper.startsWith('FILE:///') ||
        upper.contains('LOCALHOST:');
  }
}

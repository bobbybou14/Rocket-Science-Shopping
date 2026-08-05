import 'package:flutter/foundation.dart';

class ReceiptLayoutProductBlock {
  final List<String> nameLines;
  final List<String> detailLines;
  final String priceLine;
  final double price;
  final bool needsReview;
  final double confidenceScore;

  const ReceiptLayoutProductBlock({
    required this.nameLines,
    required this.detailLines,
    required this.priceLine,
    required this.price,
    required this.needsReview,
    required this.confidenceScore,
  });

  String get name => nameLines.join(' ').trim();

  String get combinedText {
    return <String>[...nameLines, ...detailLines, priceLine].join(' ');
  }
}

class ReceiptLayoutBuildResult {
  final List<ReceiptLayoutProductBlock> products;
  final List<String> headerLines;
  final List<String> orphanLines;
  final List<String> totalsAndFooterLines;

  const ReceiptLayoutBuildResult({
    required this.products,
    required this.headerLines,
    required this.orphanLines,
    required this.totalsAndFooterLines,
  });
}

class ReceiptLayoutBlockBuilder {
  const ReceiptLayoutBlockBuilder._();

  static ReceiptLayoutBuildResult build(List<String> sourceLines) {
    final lines = sourceLines
        .map(_cleanLine)
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const ReceiptLayoutBuildResult(
        products: <ReceiptLayoutProductBlock>[],
        headerLines: <String>[],
        orphanLines: <String>[],
        totalsAndFooterLines: <String>[],
      );
    }

    final products = <ReceiptLayoutProductBlock>[];
    final headerLines = <String>[];
    final orphanLines = <String>[];
    final totalsAndFooterLines = <String>[];

    final totalsIndex = _findTotalsStart(lines);
    final itemSectionEnd = totalsIndex < 0 ? lines.length : totalsIndex;

    final candidateLines = lines.sublist(0, itemSectionEnd);

    if (totalsIndex >= 0) {
      totalsAndFooterLines.addAll(lines.sublist(totalsIndex));
    }

    final anchorIndexes = <int>[];

    for (var index = 0; index < candidateLines.length; index++) {
      if (_isSellingPriceAnchor(candidateLines[index])) {
        anchorIndexes.add(index);
      }
    }

    if (anchorIndexes.isEmpty) {
      headerLines.addAll(candidateLines);

      return ReceiptLayoutBuildResult(
        products: const <ReceiptLayoutProductBlock>[],
        headerLines: List<String>.unmodifiable(headerLines),
        orphanLines: const <String>[],
        totalsAndFooterLines: List<String>.unmodifiable(totalsAndFooterLines),
      );
    }

    final firstAnchorIndex = anchorIndexes.first;
    final firstProductStart = _findProductStart(
      lines: candidateLines,
      anchorIndex: firstAnchorIndex,
      minimumIndex: 0,
      isFirstProduct: true,
    );

    if (firstProductStart > 0) {
      headerLines.addAll(candidateLines.sublist(0, firstProductStart));
    }

    var consumedThrough = firstProductStart - 1;

    for (
      var anchorPosition = 0;
      anchorPosition < anchorIndexes.length;
      anchorPosition++
    ) {
      final anchorIndex = anchorIndexes[anchorPosition];

      final minimumIndex = consumedThrough + 1;

      final productStart = _findProductStart(
        lines: candidateLines,
        anchorIndex: anchorIndex,
        minimumIndex: minimumIndex,
        isFirstProduct: products.isEmpty,
      );

      if (productStart > minimumIndex) {
        final gapLines = candidateLines.sublist(minimumIndex, productStart);

        for (final gapLine in gapLines) {
          if (_looksLikeHeaderLine(gapLine) && products.isEmpty) {
            headerLines.add(gapLine);
          } else {
            orphanLines.add(gapLine);
          }
        }
      }

      final blockLines = candidateLines.sublist(productStart, anchorIndex + 1);

      final block = _buildProductBlock(blockLines);

      if (block != null) {
        products.add(block);
      } else {
        orphanLines.addAll(blockLines);
      }

      consumedThrough = anchorIndex;
    }

    if (consumedThrough + 1 < candidateLines.length) {
      orphanLines.addAll(candidateLines.sublist(consumedThrough + 1));
    }

    return ReceiptLayoutBuildResult(
      products: List<ReceiptLayoutProductBlock>.unmodifiable(products),
      headerLines: List<String>.unmodifiable(headerLines),
      orphanLines: List<String>.unmodifiable(orphanLines),
      totalsAndFooterLines: List<String>.unmodifiable(totalsAndFooterLines),
    );
  }

  static void debugPrintResult(ReceiptLayoutBuildResult result) {
    final reviewCount = result.products
        .where((product) => product.needsReview)
        .length;

    debugPrint('----- RECEIPT LAYOUT V2 START -----');
    debugPrint('Product anchor count: ${result.products.length}');
    debugPrint('Needs-review count: $reviewCount');
    debugPrint('Header line count: ${result.headerLines.length}');
    debugPrint('Orphan line count: ${result.orphanLines.length}');
    debugPrint(
      'Totals/footer line count: '
      '${result.totalsAndFooterLines.length}',
    );

    for (var index = 0; index < result.products.length; index++) {
      final product = result.products[index];

      debugPrint(
        'PRODUCT ${index + 1}: '
        '\$${product.price.toStringAsFixed(2)}',
      );

      debugPrint('  NEEDS REVIEW: ${product.needsReview}');

      debugPrint(
        '  CONFIDENCE: '
        '${product.confidenceScore.toStringAsFixed(0)}',
      );

      if (product.nameLines.isEmpty) {
        debugPrint('  NAME: <MISSING>');
      } else {
        for (
          var nameIndex = 0;
          nameIndex < product.nameLines.length;
          nameIndex++
        ) {
          debugPrint(
            '  NAME ${nameIndex + 1}: '
            '${product.nameLines[nameIndex]}',
          );
        }
      }

      if (product.detailLines.isEmpty) {
        debugPrint('  DETAILS: <NONE>');
      } else {
        for (
          var detailIndex = 0;
          detailIndex < product.detailLines.length;
          detailIndex++
        ) {
          debugPrint(
            '  DETAIL ${detailIndex + 1}: '
            '${product.detailLines[detailIndex]}',
          );
        }
      }

      debugPrint('  PRICE LINE: ${product.priceLine}');
    }

    if (result.orphanLines.isNotEmpty) {
      debugPrint('ORPHAN OCR LINES:');

      for (var index = 0; index < result.orphanLines.length; index++) {
        debugPrint('  ORPHAN ${index + 1}: ${result.orphanLines[index]}');
      }
    }

    debugPrint('----- RECEIPT LAYOUT V2 END -----');
  }

  static ReceiptLayoutProductBlock? _buildProductBlock(
    List<String> blockLines,
  ) {
    if (blockLines.isEmpty) {
      return null;
    }

    final priceLine = blockLines.last;
    final price = _extractFinalAmount(priceLine);

    if (price == null || price <= 0) {
      return null;
    }

    final precedingLines = blockLines.length > 1
        ? blockLines.sublist(0, blockLines.length - 1)
        : const <String>[];

    final nameLines = <String>[];
    final detailLines = <String>[];

    for (final line in precedingLines) {
      if (_looksLikeDetailLine(line)) {
        detailLines.add(line);
      } else if (_looksLikePossibleName(line)) {
        nameLines.add(line);
      } else {
        detailLines.add(line);
      }
    }

    final anchorName = _extractNameFromAnchor(priceLine);

    if (anchorName.isNotEmpty) {
      nameLines.add(anchorName);
    }

    final name = nameLines.join(' ').trim();
    final nameQuality = _calculateNameQuality(name);

    final confidenceScore = _calculateBlockConfidence(
      nameQuality: nameQuality,
      hasDetails: detailLines.isNotEmpty,
      priceLine: priceLine,
    );

    final needsReview =
        nameLines.isEmpty || nameQuality < 65 || confidenceScore < 80;

    return ReceiptLayoutProductBlock(
      nameLines: List<String>.unmodifiable(nameLines),
      detailLines: List<String>.unmodifiable(detailLines),
      priceLine: priceLine,
      price: price,
      needsReview: needsReview,
      confidenceScore: confidenceScore,
    );
  }

  static int _findProductStart({
    required List<String> lines,
    required int anchorIndex,
    required int minimumIndex,
    required bool isFirstProduct,
  }) {
    if (anchorIndex <= minimumIndex) {
      return anchorIndex;
    }

    var start = anchorIndex;

    // Product information generally occupies the anchor line plus up to
    // two preceding lines. A third line is accepted only when it is a
    // strong pricing, quantity, weight, or barcode detail.
    final searchFloor = (anchorIndex - 3) > minimumIndex
        ? anchorIndex - 3
        : minimumIndex;

    var acceptedNameLine = false;
    var acceptedDetailLine = false;

    for (var index = anchorIndex - 1; index >= searchFloor; index--) {
      final line = lines[index];

      if (_looksLikeSectionBoundary(line) ||
          _isSellingPriceAnchor(line) ||
          _looksLikeHeaderLine(line) ||
          _looksLikeDepartmentLine(line) ||
          _looksLikeLoyaltyLine(line.toUpperCase())) {
        break;
      }

      if (_looksLikeDetailLine(line)) {
        if (acceptedDetailLine && acceptedNameLine) {
          break;
        }

        start = index;
        acceptedDetailLine = true;
        continue;
      }

      if (_looksLikeStrongNameCandidate(line)) {
        if (acceptedNameLine) {
          break;
        }

        start = index;
        acceptedNameLine = true;
        continue;
      }

      // Tiny OCR fragments such as "at" and "Be]" must not be attached
      // to the following product.
      if (_looksLikeWeakStandaloneFragment(line)) {
        break;
      }

      // For the first product, do not absorb uncertain receipt-header
      // content merely because it occurs immediately before the price.
      if (isFirstProduct) {
        break;
      }

      break;
    }

    return start;
  }

  static bool _isSellingPriceAnchor(String line) {
    final upper = line.toUpperCase();
    final normalized = _normalizeLabel(line);

    if (_isTotalsLine(upper, normalized) ||
        _isPaymentLine(upper) ||
        _looksLikeDateOrTime(line) ||
        _looksLikeLoyaltyLine(upper)) {
      return false;
    }

    final amounts = _extractAmounts(line);

    if (amounts.isEmpty) {
      return false;
    }

    final finalAmount = amounts.last;

    if (finalAmount <= 0 || finalAmount > 5000) {
      return false;
    }

    if (_looksLikeTaxRateLine(line)) {
      return false;
    }

    // A receipt item can contain:
    // - name and final price on the same line;
    // - quantity/unit price/final price;
    // - a final amount by itself.
    return true;
  }

  static bool _looksLikePossibleName(String line) {
    final upper = line.toUpperCase();

    if (_looksLikeSectionBoundary(line) ||
        _looksLikeHeaderLine(line) ||
        _looksLikeDepartmentLine(line) ||
        _looksLikeLoyaltyLine(upper) ||
        _looksLikeDateOrTime(line) ||
        _looksLikeBarcodeOnly(line)) {
      return false;
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;

    return letterCount >= 2;
  }

  static bool _looksLikeStrongNameCandidate(String line) {
    if (!_looksLikePossibleName(line)) {
      return false;
    }

    final trimmed = line.trim();
    final letterCount = RegExp(r'[A-Za-z]').allMatches(trimmed).length;
    final words = RegExp(r'[A-Za-z][A-Za-z0-9]*')
        .allMatches(trimmed)
        .map((match) => match.group(0) ?? '')
        .where((word) => word.length >= 2)
        .toList();

    if (letterCount < 5 || words.length < 2) {
      return false;
    }

    final punctuationCount = RegExp(
      r'[^A-Za-z0-9\s]',
    ).allMatches(trimmed).length;

    if (punctuationCount > 3 && punctuationCount >= words.length) {
      return false;
    }

    return true;
  }

  static bool _looksLikeWeakStandaloneFragment(String line) {
    final trimmed = line.trim();
    final letterCount = RegExp(r'[A-Za-z]').allMatches(trimmed).length;
    final wordCount = RegExp(r'[A-Za-z0-9]+').allMatches(trimmed).length;

    if (trimmed.length <= 4) {
      return true;
    }

    if (letterCount < 4 || wordCount < 2) {
      return true;
    }

    return false;
  }

  static bool _looksLikeDepartmentLine(String line) {
    return RegExp(
      r'^\s*[^A-Za-z0-9]*\d{1,3}\s*-\s*[A-Za-z]',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static bool _looksLikeDetailLine(String line) {
    final upper = line.toUpperCase();

    if (_looksLikeBarcodeOnly(line)) {
      return true;
    }

    if (RegExp(
      r'\b\d+(?:\.\d+)?\s*(?:KG|LB|LBS)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    if (upper.contains('/KG') || upper.contains('/LB')) {
      return true;
    }

    if (RegExp(
      r'^\s*\(\s*\d+(?:\.\d+)?\s*\)\s*(?:[@X]|EA\b)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    if (RegExp(
      r'\bQTY\s*[:X@]?\s*\d+(?:\.\d+)?',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    if (RegExp(
      r'\b\d+(?:\.\d+)?\s*[@X]\s*\$?\s*\d+\.\d{2}',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    final amountCount = _extractAmounts(line).length;
    final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;

    if (amountCount >= 2 && letterCount <= 5) {
      return true;
    }

    // Windows OCR may merge a quantity, unit price, and line total:
    // "(2) @ 3.00 6.00" can become "2483.00 6.00".
    if (RegExp(r'^\s*\d{1,4}\d+\.\d{2}\s+\d+\.\d{2}\s*$').hasMatch(line)) {
      return true;
    }

    return amountCount > 0 && letterCount <= 5;
  }

  static String _extractNameFromAnchor(String line) {
    var value = line;

    value = value.replaceAll(
      RegExp(
        r'-?\s*\$?\s*'
        r'((?:\d{1,3}(?:,\d{3})*)|\d+)'
        r'\.\d{2}\s*-?',
      ),
      ' ',
    );

    value = value
        .replaceAll(
          RegExp(r'\b\d+(?:\.\d+)?\s*(?:KG|LB|LBS)\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'\bQTY\s*[:X@]?\s*\d+(?:\.\d+)?', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b\d+(?:\.\d+)?\s*[@X]\s*', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final letterCount = RegExp(r'[A-Za-z]').allMatches(value).length;

    if (letterCount < 2) {
      return '';
    }

    return value;
  }

  static double _calculateNameQuality(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return 0;
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(trimmed).length;
    final digitCount = RegExp(r'\d').allMatches(trimmed).length;
    final punctuationCount = RegExp(
      r'[^A-Za-z0-9\s]',
    ).allMatches(trimmed).length;

    final words = RegExp(
      r'[A-Za-z0-9]+',
    ).allMatches(trimmed).map((match) => match.group(0) ?? '').toList();

    final meaningfulWords = words.where((word) => word.length >= 3).length;

    var score = 0.0;

    if (letterCount >= 4) {
      score += 20;
    }

    if (letterCount >= 8) {
      score += 15;
    }

    if (meaningfulWords >= 2) {
      score += 25;
    }

    if (meaningfulWords >= 3) {
      score += 10;
    }

    final uppercaseLikeWords = words.where((word) {
      if (word.length < 3) {
        return false;
      }

      final letters = word.replaceAll(RegExp(r'[^A-Za-z]'), '');

      if (letters.isEmpty) {
        return false;
      }

      return letters == letters.toUpperCase();
    }).length;

    if (uppercaseLikeWords >= 2) {
      score += 15;
    }

    if (punctuationCount >= 2) {
      score -= 10;
    }

    if (punctuationCount > meaningfulWords) {
      score -= 20;
    }

    if (digitCount > letterCount) {
      score -= 20;
    }

    if (_containsLikelyOcrGarbage(trimmed)) {
      score -= 40;
    }

    if (RegExp(r'^\D*\d{6,}').hasMatch(trimmed)) {
      // OCR often drags part of a barcode into the product name.
      score -= 20;
    }

    final mixedCaseWords = words.where((word) {
      return word != word.toUpperCase() && word != word.toLowerCase();
    }).length;

    if (mixedCaseWords >= 2) {
      score -= 15;
    }
    return score.clamp(0, 100).toDouble();
  }

  static bool _containsLikelyOcrGarbage(String value) {
    final words = RegExp(r'[A-Za-z]+')
        .allMatches(value)
        .map((match) => match.group(0) ?? '')
        .where((word) => word.length >= 4)
        .toList();

    if (words.isEmpty) {
      return true;
    }

    var suspiciousWords = 0;

    for (final word in words) {
      final lower = word.toLowerCase();

      final vowelCount = RegExp(r'[aeiouy]').allMatches(lower).length;

      final consonantRun = RegExp(
        r'[^aeiouy]{5,}',
        caseSensitive: false,
      ).hasMatch(lower);

      if (vowelCount == 0 || consonantRun) {
        suspiciousWords++;
      }
    }

    return suspiciousWords >= 2 || suspiciousWords == words.length;
  }

  static double _calculateBlockConfidence({
    required double nameQuality,
    required bool hasDetails,
    required String priceLine,
  }) {
    var score = 25.0;

    score += nameQuality * 0.5;

    if (hasDetails) {
      score += 8;
    }

    if (_extractFinalAmount(priceLine) != null) {
      score += 7;
    }

    return score.clamp(0, 100).toDouble();
  }

  static int _findTotalsStart(List<String> lines) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final upper = line.toUpperCase();
      final normalized = _normalizeLabel(line);

      if (_isTotalsLine(upper, normalized)) {
        return index;
      }
    }

    return -1;
  }

  static bool _looksLikeSectionBoundary(String line) {
    final upper = line.toUpperCase();
    final normalized = _normalizeLabel(line);

    return _isTotalsLine(upper, normalized) ||
        _isPaymentLine(upper) ||
        _looksLikeDateOrTime(line);
  }

  static bool _looksLikeHeaderLine(String line) {
    final upper = line.toUpperCase();

    if (upper.contains('WELCOME') ||
        upper.contains('INDEPENDENT GROCER') ||
        upper.contains('YOUR INDEPENDENT') ||
        upper.contains('WALMART') ||
        upper.contains('COSTCO') ||
        upper.contains('STORE #') ||
        upper.contains('STORE NO') ||
        upper.contains('RECEIPT') ||
        upper.contains('INVOICE')) {
      return true;
    }

    if (RegExp(
      r'^\s*[^A-Za-z0-9]*\d{1,3}\s*-\s*[A-Za-z]',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    return false;
  }

  static bool _looksLikeLoyaltyLine(String upper) {
    return upper.contains('POINT') ||
        upper.contains('PTS') ||
        upper.contains('REDEEM') ||
        upper.contains('EARNED') ||
        upper.contains('BALANCE');
  }

  static bool _looksLikeDateOrTime(String line) {
    return RegExp(r'\b\d{4}[-/]\d{1,2}[-/]\d{1,2}\b').hasMatch(line) ||
        RegExp(r'\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b').hasMatch(line) ||
        RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b').hasMatch(line);
  }

  static bool _looksLikeTaxRateLine(String line) {
    return RegExp(r'\d+(?:\.\d+)?\s*%', caseSensitive: false).hasMatch(line);
  }

  static bool _isTotalsLine(String upper, String normalized) {
    return upper.contains('SUBTOTAL') ||
        upper.contains('SUB TOTAL') ||
        upper == 'TOTAL' ||
        upper.startsWith('TOTAL ') ||
        upper.contains('GRAND TOTAL') ||
        upper.contains('TOTAL DUE') ||
        upper.contains('AMOUNT DUE') ||
        upper.contains('HST') ||
        upper.contains('GST') ||
        upper.contains('PST') ||
        upper.startsWith('TAX ') ||
        normalized == 'TAX' ||
        normalized.startsWith('SUPR') ||
        normalized.startsWith('SUBT') ||
        normalized.contains('UPRORA') ||
        normalized.contains('UBTOTA') ||
        normalized == 'TORAT' ||
        normalized == 'RORAT' ||
        normalized.startsWith('TOTAI');
  }

  static bool _isPaymentLine(String upper) {
    return upper.contains('CHANGE') ||
        upper.contains('CASH') ||
        upper.contains('PAYMENT') ||
        upper.contains('TENDER') ||
        upper.contains('AMOUNT PAID') ||
        upper.contains('PAID') ||
        upper.contains('MASTERCARD') ||
        upper.contains('VISA') ||
        upper.contains('DEBIT') ||
        upper.contains('CREDIT') ||
        upper.contains('APPROVED') ||
        upper.contains('AUTH') ||
        upper.contains('THANK YOU');
  }

  static bool _looksLikeBarcodeOnly(String line) {
    final compact = line.replaceAll(RegExp(r'[\s\-]'), '');

    return RegExp(r'^\d{8,14}$').hasMatch(compact);
  }

  static List<double> _extractAmounts(String line) {
    final matches = RegExp(
      r'-?\s*\$?\s*'
      r'((?:\d{1,3}(?:,\d{3})*)|\d+)'
      r'\.\d{2}\s*-?',
    ).allMatches(line);

    final amounts = <double>[];

    for (final match in matches) {
      final raw = match.group(0) ?? '';
      final trimmed = raw.trim();

      final negative = trimmed.startsWith('-') || trimmed.endsWith('-');

      final cleaned = trimmed
          .replaceAll('\$', '')
          .replaceAll(',', '')
          .replaceAll('-', '')
          .replaceAll(' ', '');

      final amount = double.tryParse(cleaned);

      if (amount != null) {
        amounts.add(negative ? -amount : amount);
      }
    }

    return amounts;
  }

  static double? _extractFinalAmount(String line) {
    final amounts = _extractAmounts(line);

    if (amounts.isEmpty) {
      return null;
    }

    return amounts.last.abs();
  }

  static String _cleanLine(String line) {
    return line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  static String _normalizeLabel(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  }
}

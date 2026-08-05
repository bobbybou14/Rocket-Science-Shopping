import 'package:flutter/foundation.dart';

enum ReceiptBlockType {
  product,
  receiptInfo,
  totals,
  payment,
  metadata,
  unknown,
}

class ReceiptBlock {
  final ReceiptBlockType type;
  final List<String> lines;

  const ReceiptBlock({required this.type, required this.lines});

  String get combinedText => lines.join(' ');

  bool get isProduct => type == ReceiptBlockType.product;

  @override
  String toString() {
    return 'ReceiptBlock(type: ${type.name}, lines: $lines)';
  }
}

class ReceiptBlockBuilder {
  const ReceiptBlockBuilder._();

  static List<ReceiptBlock> build(List<String> sourceLines) {
    final lines = sourceLines
        .map(_cleanLine)
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const <ReceiptBlock>[];
    }

    final blocks = <ReceiptBlock>[];
    final pendingProductLines = <String>[];

    bool itemSectionStarted = false;
    bool totalsSectionStarted = false;

    void flushPendingProduct() {
      if (pendingProductLines.isEmpty) {
        return;
      }

      blocks.add(
        ReceiptBlock(
          type: ReceiptBlockType.product,
          lines: List<String>.unmodifiable(pendingProductLines),
        ),
      );

      pendingProductLines.clear();
    }

    void appendSectionLine(ReceiptBlockType type, String line) {
      if (blocks.isNotEmpty && blocks.last.type == type) {
        final previous = blocks.removeLast();

        blocks.add(
          ReceiptBlock(
            type: type,
            lines: List<String>.unmodifiable(<String>[...previous.lines, line]),
          ),
        );

        return;
      }

      blocks.add(
        ReceiptBlock(
          type: type,
          lines: List<String>.unmodifiable(<String>[line]),
        ),
      );
    }

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final nextLine = index + 1 < lines.length ? lines[index + 1] : null;

      final fixedType = _fixedBlockType(line);

      if (totalsSectionStarted) {
        flushPendingProduct();

        final postTotalType = fixedType == ReceiptBlockType.payment
            ? ReceiptBlockType.payment
            : ReceiptBlockType.metadata;

        appendSectionLine(postTotalType, line);
        continue;
      }

      if (fixedType != null) {
        flushPendingProduct();

        if (fixedType == ReceiptBlockType.totals) {
          totalsSectionStarted = true;
        }

        appendSectionLine(fixedType, line);
        continue;
      }

      if (_looksLikeCompleteProductLine(line)) {
        flushPendingProduct();
        itemSectionStarted = true;
        pendingProductLines.add(line);

        if (nextLine == null || !_looksLikeProductContinuation(nextLine)) {
          flushPendingProduct();
        }

        continue;
      }

      final strongProductName = _looksLikeStrongProductName(line);

      final hasUsableContinuation =
          nextLine != null &&
          (_looksLikeProductContinuation(nextLine) ||
              _looksLikeCompleteProductLine(nextLine));

      if (strongProductName && (itemSectionStarted || hasUsableContinuation)) {
        flushPendingProduct();
        pendingProductLines.add(line);

        if (nextLine == null) {
          flushPendingProduct();
        }

        continue;
      }

      if (pendingProductLines.isNotEmpty &&
          _looksLikeProductContinuation(line)) {
        pendingProductLines.add(line);
        itemSectionStarted = true;

        if (nextLine == null ||
            _startsNewSection(nextLine) ||
            _looksLikeCompleteProductLine(nextLine) ||
            _looksLikeStrongProductName(nextLine)) {
          flushPendingProduct();
        }

        continue;
      }

      flushPendingProduct();

      appendSectionLine(
        itemSectionStarted
            ? ReceiptBlockType.unknown
            : ReceiptBlockType.receiptInfo,
        line,
      );
    }

    flushPendingProduct();

    return List<ReceiptBlock>.unmodifiable(blocks);
  }

  static void debugPrintBlocks(List<ReceiptBlock> blocks) {
    final productCount = blocks.where((block) => block.isProduct).length;

    debugPrint('----- RECEIPT BLOCKS START -----');
    debugPrint('Receipt block count: ${blocks.length}');
    debugPrint('Product block count: $productCount');

    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];

      debugPrint('BLOCK ${index + 1}: ${block.type.name.toUpperCase()}');

      for (var lineIndex = 0; lineIndex < block.lines.length; lineIndex++) {
        debugPrint('  LINE ${lineIndex + 1}: ${block.lines[lineIndex]}');
      }
    }

    debugPrint('----- RECEIPT BLOCKS END -----');
  }

  static String _cleanLine(String line) {
    return line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  static ReceiptBlockType? _fixedBlockType(String line) {
    final upper = line.toUpperCase();
    final normalized = _normalizeLabel(line);

    if (_isTotalsLine(upper, normalized)) {
      return ReceiptBlockType.totals;
    }

    if (_isPaymentLine(upper)) {
      return ReceiptBlockType.payment;
    }

    if (_isMetadataLine(upper)) {
      return ReceiptBlockType.metadata;
    }

    if (_isReceiptInformationLine(upper)) {
      return ReceiptBlockType.receiptInfo;
    }

    return null;
  }

  static bool _startsNewSection(String line) {
    return _fixedBlockType(line) != null;
  }

  static bool _looksLikeCompleteProductLine(String line) {
    if (_extractAmounts(line).isEmpty) {
      return false;
    }

    if (_looksLikeTotalOrPayment(line)) {
      return false;
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;
    final hasProductCode = RegExp(r'\b\d{6,14}\b').hasMatch(line);

    return letterCount >= 2 || hasProductCode;
  }

  static bool _looksLikeProductName(String line) {
    final upper = line.toUpperCase();
    final normalized = _normalizeLabel(line);

    if (_extractAmounts(line).isNotEmpty ||
        _looksLikeBarcodeOnly(line) ||
        _fixedBlockType(line) != null ||
        _looksLikeAddressOrPhone(line)) {
      return false;
    }

    if (_isTotalsLine(upper, normalized) ||
        _isPaymentLine(upper) ||
        _isMetadataLine(upper)) {
      return false;
    }

    if (RegExp(r'^\d{1,2}-[A-Z]').hasMatch(upper)) {
      return false;
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;
    final wordCount = RegExp(r'[A-Za-z0-9]+').allMatches(line).length;
    final digitCount = RegExp(r'\d').allMatches(line).length;

    if (letterCount < 4 || wordCount < 2) {
      return false;
    }

    if (digitCount > letterCount + 6) {
      return false;
    }

    return true;
  }

  static bool _looksLikeStrongProductName(String line) {
    if (!_looksLikeProductName(line)) {
      return false;
    }

    final trimmed = line.trim();
    final letterCount = RegExp(r'[A-Za-z]').allMatches(trimmed).length;
    final punctuationCount = RegExp(
      r'[^A-Za-z0-9\s]',
    ).allMatches(trimmed).length;
    final wordMatches = RegExp(
      r'[A-Za-z][A-Za-z0-9]*',
    ).allMatches(trimmed).toList();

    if (letterCount < 5 || wordMatches.isEmpty) {
      return false;
    }

    // Reject OCR fragments dominated by symbols and punctuation.
    if (punctuationCount > 2 && punctuationCount >= wordMatches.length) {
      return false;
    }

    final meaningfulWords = wordMatches.where((match) {
      final word = match.group(0) ?? '';
      return word.length >= 2;
    }).length;

    if (meaningfulWords < 2) {
      return false;
    }

    // Reject common receipt headings and loyalty/footer language even
    // when OCR corruption prevents exact metadata matching.
    final upper = trimmed.toUpperCase();

    const rejectedTerms = <String>[
      'POINT',
      'PTS',
      'REDEEM',
      'EARNED',
      'LEARN MORE',
      'CLOSING',
      'STATEMENT',
      'TRANSACTION',
      'DATELINE',
      'RETAIN',
      'APPROVED',
      'THANK',
      'COMMERCIAL',
      'DEPARTMENT',
    ];

    for (final term in rejectedTerms) {
      if (upper.contains(term)) {
        return false;
      }
    }

    // Common receipt department headings, for example:
    // "34-BAKERY", "12-GROCERY", or OCR-corrupted variants.
    if (RegExp(
      r'^\s*[^A-Za-z0-9]*\d{1,3}\s*-\s*[A-Za-z]',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return false;
    }

    return true;
  }

  static bool _looksLikeProductContinuation(String line) {
    final upper = line.toUpperCase();

    if (_fixedBlockType(line) != null) {
      return false;
    }

    if (_looksLikeWeightedDetail(upper)) {
      return true;
    }

    if (_looksLikeQuantityDetail(line)) {
      return true;
    }

    if (_looksLikeAmountOnly(line)) {
      return true;
    }

    if (_looksLikeBarcodeOnly(line)) {
      return true;
    }

    final amounts = _extractAmounts(line);
    final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;

    return amounts.isNotEmpty && letterCount <= 5;
  }

  static bool _looksLikeWeightedDetail(String upper) {
    return RegExp(
          r'\b\d+(?:\.\d+)?\s*(?:KG|LB|LBS)\b',
          caseSensitive: false,
        ).hasMatch(upper) ||
        upper.contains('/KG') ||
        upper.contains('/LB');
  }

  static bool _looksLikeQuantityDetail(String line) {
    if (RegExp(
      r'^\s*\(\s*\d+(?:\.\d+)?\s*\)\s*(?:[@X]|EA\b)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    if (RegExp(
      r'^\s*\d+(?:\.\d+)?\s*[@X]\s*\$?\s*\d+\.\d{2}',
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

    if (RegExp(r'\b\d+\s+(?:FOR|EA)\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }

    if (RegExp(
      r'\b\d+\s*/\s*\$?\s*\d+(?:\.\d{1,2})?',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    final amountCount = _extractAmounts(line).length;
    final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;

    return amountCount >= 2 && letterCount <= 6;
  }

  static bool _looksLikeAmountOnly(String line) {
    return RegExp(
      r'^\s*'
      r'\$?\s*\d+\.\d{2}'
      r'(?:\s+[A-Z])?'
      r'\s*$',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static bool _looksLikeBarcodeOnly(String line) {
    final compact = line.replaceAll(RegExp(r'[\s\-]'), '');

    return RegExp(r'^\d{8,14}$').hasMatch(compact);
  }

  static bool _looksLikeAddressOrPhone(String line) {
    final upper = line.toUpperCase();

    final hasPhoneNumber = RegExp(
      r'\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b',
    ).hasMatch(line);

    final hasPostalCode = RegExp(
      r'\b[A-Z]\d[A-Z]\s?\d[A-Z]\d\b',
      caseSensitive: false,
    ).hasMatch(line);

    final hasStreetWord =
        upper.contains(' STREET') ||
        upper.contains(' ST.') ||
        upper.contains(' ROAD') ||
        upper.contains(' RD.') ||
        upper.contains(' AVENUE') ||
        upper.contains(' AVE.') ||
        upper.contains(' DRIVE') ||
        upper.contains(' DR.') ||
        upper.contains(' HIGHWAY') ||
        upper.contains(' HWY');

    return hasPhoneNumber || hasPostalCode || hasStreetWord;
  }

  static bool _looksLikeTotalOrPayment(String line) {
    final upper = line.toUpperCase();
    final normalized = _normalizeLabel(line);

    return _isTotalsLine(upper, normalized) || _isPaymentLine(upper);
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
        _looksLikeCorruptedSubtotal(normalized) ||
        _looksLikeCorruptedTotal(normalized);
  }

  static bool _looksLikeCorruptedSubtotal(String normalized) {
    if (normalized.length < 5) {
      return false;
    }

    return normalized.startsWith('SUPR') ||
        normalized.startsWith('SUBT') ||
        normalized.contains('UPRORA') ||
        normalized.contains('UBTOTA');
  }

  static bool _looksLikeCorruptedTotal(String normalized) {
    if (normalized.length < 4) {
      return false;
    }

    return normalized == 'TORAT' ||
        normalized == 'RORAT' ||
        normalized.startsWith('TOTAI') ||
        normalized.startsWith('T0TAL');
  }

  static bool _isPaymentLine(String upper) {
    return upper.contains('CHANGE') ||
        upper.contains('BALANCE') ||
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

  static bool _isMetadataLine(String upper) {
    return upper.contains('ORDERS & PURCHASES') ||
        upper.contains('ORDERS AND PURCHASES') ||
        upper.contains('MY ACCOUNT') ||
        upper.contains('PAGE 1 OF') ||
        upper.contains('PAGE 2 OF') ||
        upper.contains('HTTP://') ||
        upper.contains('HTTPS://') ||
        upper.contains('WWW.') ||
        upper.contains('PRINTED FROM') ||
        upper.contains('DOWNLOAD') ||
        upper.contains('SCREENSHOT') ||
        upper.contains('VIEW IN BROWSER');
  }

  static bool _isReceiptInformationLine(String upper) {
    return upper.contains('RECEIPT') ||
        upper.contains('INVOICE') ||
        upper.contains('CASHIER') ||
        upper.contains('REGISTER') ||
        upper.contains('STORE #') ||
        upper.contains('STORE NO') ||
        upper.contains('CUSTOMER COPY') ||
        upper.contains('MERCHANT COPY') ||
        upper.contains('POINTS BALANCE') ||
        upper.contains('POINTS EARNED') ||
        upper.contains('ITEMS SOLD') ||
        upper.contains('ITEM COUNT') ||
        upper.contains('WELCOME') ||
        upper.contains('SUPERCENTRE') ||
        upper.contains('WE SELL FOR LESS') ||
        upper.contains('INDEPENDENT GROCER') ||
        upper.contains('YOUR INDEPENDENT') ||
        upper.contains('WALMART') ||
        upper.contains('COSTCO') ||
        upper.contains('DATELINE:') ||
        upper.contains('TRANS.') ||
        upper.contains('TRANSACTION');
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

  static String _normalizeLabel(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  }
}

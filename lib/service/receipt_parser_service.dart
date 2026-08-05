import 'receipt_block_builder.dart';
import 'receipt_layout_block_builder.dart';

class ParsedReceipt {
  final String storeName;
  final DateTime? purchaseDate;
  final double subtotal;
  final double tax;
  final double total;
  final List<ParsedReceiptItem> items;
  final List<String> ignoredSensitiveLines;

  const ParsedReceipt({
    this.storeName = '',
    this.purchaseDate,
    this.subtotal = 0,
    this.tax = 0,
    this.total = 0,
    this.items = const [],
    this.ignoredSensitiveLines = const [],
  });
}

class ParsedReceiptItem {
  final String name;
  final double price;
  final double quantity;
  final double confidenceScore;
  final bool isDiscount;
  final bool isWeightedItem;

  const ParsedReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.confidenceScore = 70,
    this.isDiscount = false,
    this.isWeightedItem = false,
  });
}

class ReceiptParserService {
  const ReceiptParserService._();

  static ParsedReceipt parse(String rawText) {
    final lines = _cleanLines(rawText);

    assert(() {
      final blocks = ReceiptBlockBuilder.build(lines);
      ReceiptBlockBuilder.debugPrintBlocks(blocks);

      final layoutResult = ReceiptLayoutBlockBuilder.build(lines);
      ReceiptLayoutBlockBuilder.debugPrintResult(layoutResult);

      return true;
    }());

    final ignoredSensitiveLines = <String>[];
    final items = <ParsedReceiptItem>[];

    String storeName = '';
    DateTime? purchaseDate;
    double subtotal = 0;
    double tax = 0;
    double total = 0;

    bool totalsSectionStarted = false;
    String? pendingItemName;

    for (final line in lines) {
      final upper = line.toUpperCase();
      final normalizedLabel = _normalizeLabel(line);

      if (_isSensitiveLine(upper)) {
        ignoredSensitiveLines.add(line);
        continue;
      }

      if (_isMetadataLine(upper)) {
        pendingItemName = null;
        continue;
      }

      if (storeName.isEmpty) {
        storeName = _detectStoreName(line);
      }

      purchaseDate ??= _detectDate(line);

      if (_isSubtotalLine(upper, normalizedLabel)) {
        final amount = _extractAmount(line);

        if (amount != null) {
          subtotal = amount.abs();
          totalsSectionStarted = true;
          pendingItemName = null;
        }

        continue;
      }

      if (_isTaxLine(upper, normalizedLabel)) {
        final amount = _extractTaxAmount(line);

        if (amount != null) {
          tax += amount.abs();
        }

        totalsSectionStarted = true;
        pendingItemName = null;
        continue;
      }

      if (_isTotalLine(upper, normalizedLabel)) {
        final amount = _extractAmount(line);

        if (amount != null) {
          total = amount.abs();
        }

        totalsSectionStarted = true;
        pendingItemName = null;
        continue;
      }

      if (_isPaymentOrFooterLine(upper)) {
        totalsSectionStarted = true;
        pendingItemName = null;
        continue;
      }

      if (_isNonProductLine(upper, normalizedLabel)) {
        pendingItemName = null;
        continue;
      }

      if (_looksLikeBarcodeOnly(line)) {
        continue;
      }

      if (_looksLikeAddressOrPhone(line)) {
        continue;
      }

      final amount = _extractAmount(line);

      if (amount == null) {
        if (!totalsSectionStarted &&
            (_looksLikeSplitItemName(line) ||
                _looksLikeStandaloneProductName(line))) {
          final possibleItemName = _cleanItemName(line);

          if (_isValidItemName(possibleItemName)) {
            pendingItemName = possibleItemName;
          }
        }

        continue;
      }

      if (totalsSectionStarted && !_isDiscountLine(upper)) {
        pendingItemName = null;
        continue;
      }

      var name = _cleanItemName(_removeAmounts(line));

      final isPriceContinuationLine =
          pendingItemName != null &&
          (_looksLikePriceContinuation(line) ||
              _looksLikeQuantityPriceContinuation(line) ||
              _looksLikeAmountOnlyContinuation(line));

      if (isPriceContinuationLine) {
        name = pendingItemName;
      }

      pendingItemName = null;

      if (!_isValidItemName(name)) {
        continue;
      }

      final quantity = _detectQuantity(line);
      final isDiscount = _isDiscountLine(upper);

      if (_isLinkedProductDiscountLine(upper) && items.isNotEmpty) {
        final previousItem = items.removeLast();
        final adjustedPrice = previousItem.price - amount.abs();

        items.add(
          ParsedReceiptItem(
            name: previousItem.name,
            price: adjustedPrice < 0 ? 0 : adjustedPrice,
            quantity: previousItem.quantity,
            confidenceScore: previousItem.confidenceScore,
            isDiscount: false,
            isWeightedItem: previousItem.isWeightedItem,
          ),
        );

        continue;
      }

      items.add(
        ParsedReceiptItem(
          name: name,
          price: isDiscount ? -amount.abs() : amount,
          quantity: quantity,
          confidenceScore: isPriceContinuationLine
              ? 85
              : _confidenceForLine(line, itemName: name),
          isDiscount: isDiscount,
          isWeightedItem: _isWeightedLine(upper),
        ),
      );
    }

    final hasValidTotals = subtotal > 0 && total >= subtotal;

    final calculatedTax = hasValidTotals
        ? _roundCurrency(total - subtotal)
        : tax;

    final parsedAmountsDoNotBalance =
        hasValidTotals && (subtotal + tax - total).abs() > 0.02;

    final reconciledTax = parsedAmountsDoNotBalance
        ? calculatedTax
        : _roundCurrency(tax);

    return ParsedReceipt(
      storeName: storeName,
      purchaseDate: purchaseDate,
      subtotal: _roundCurrency(subtotal),
      tax: reconciledTax,
      total: _roundCurrency(total),
      items: items,
      ignoredSensitiveLines: ignoredSensitiveLines,
    );
  }

  static List<String> _cleanLines(String rawText) {
    return rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static bool _isSensitiveLine(String line) {
    return line.contains('CARD') ||
        line.contains('VISA') ||
        line.contains('MASTERCARD') ||
        line.contains('DEBIT') ||
        line.contains('CREDIT') ||
        line.contains('AUTH') ||
        line.contains('APPROVAL') ||
        line.contains('TRANSACTION') ||
        line.contains('TERMINAL') ||
        line.contains('LOYALTY') ||
        line.contains('MEMBER') ||
        line.contains('ACCOUNT') ||
        line.contains('AID') ||
        line.contains('REF #') ||
        line.contains('REFERENCE');
  }

  static bool _isMetadataLine(String line) {
    return line.contains('ORDERS & PURCHASES') ||
        line.contains('ORDERS AND PURCHASES') ||
        line.contains('MY ACCOUNT') ||
        line.contains('PAGE 1 OF') ||
        line.contains('PAGE 2 OF') ||
        line.contains('HTTP://') ||
        line.contains('HTTPS://') ||
        line.contains('MYCOSTCO') ||
        line.contains('COSTCO.CA/MYACCOUNT') ||
        line.contains('PRINTED FROM') ||
        line.contains('DOWNLOAD') ||
        line.contains('SCREENSHOT');
  }

  static bool _isSubtotalLine(String upper, String normalizedLabel) {
    return upper.contains('SUBTOTAL') ||
        upper.contains('SUB TOTAL') ||
        _approximatelyMatches(normalizedLabel, 'SUBTOTAL');
  }

  static bool _isTaxLine(String upper, String normalizedLabel) {
    return upper.contains('HST') ||
        upper.contains('GST') ||
        upper.contains('PST') ||
        upper.startsWith('TAX ') ||
        upper == 'TAX' ||
        normalizedLabel == 'HST' ||
        normalizedLabel == 'GST' ||
        normalizedLabel == 'PST' ||
        _approximatelyMatches(normalizedLabel, 'TAX');
  }

  static bool _isTotalLine(String upper, String normalizedLabel) {
    if (_isSubtotalLine(upper, normalizedLabel)) {
      return false;
    }

    return upper == 'TOTAL' ||
        upper.startsWith('TOTAL ') ||
        upper.contains('AMOUNT DUE') ||
        upper.contains('TOTAL DUE') ||
        upper.contains('GRAND TOTAL') ||
        _approximatelyMatches(normalizedLabel, 'TOTAL');
  }

  static bool _isPaymentOrFooterLine(String line) {
    return line.contains('CHANGE') ||
        line.contains('BALANCE') ||
        line.contains('CASH') ||
        line.contains('PAYMENT') ||
        line.contains('TENDER') ||
        line.contains('AMOUNT PAID') ||
        line.contains('PAID') ||
        line.contains('THANK YOU') ||
        line.contains('PLEASE COME AGAIN');
  }

  static bool _isNonProductLine(String upper, String normalizedLabel) {
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
        upper.contains('YOU SAVED') ||
        upper.contains('TOTAL SAVINGS') ||
        upper.contains('ITEMS SOLD') ||
        upper.contains('ITEM COUNT') ||
        upper.contains('OPENING HOURS') ||
        upper.contains('WWW.') ||
        upper.contains('.COM') ||
        upper.contains('.CA') ||
        normalizedLabel == 'TOTAL' ||
        normalizedLabel == 'SUBTOTAL' ||
        normalizedLabel == 'HST' ||
        normalizedLabel == 'GST' ||
        normalizedLabel == 'PST';
  }

  static bool _isDiscountLine(String line) {
    return line.contains('DISCOUNT') ||
        line.contains('COUPON') ||
        line.contains('SAVINGS') ||
        line.contains('MULTIBUY') ||
        line.contains('MULTI BUY') ||
        line.contains('PRICE MATCH') ||
        line.contains('PROMO') ||
        line.contains('LOYALTY OFFER') ||
        line.contains('STORE COUPON') ||
        line.contains('TPD/') ||
        RegExp(r'\d+\.\d{2}\s*-\s*$').hasMatch(line);
  }

  static bool _isLinkedProductDiscountLine(String line) {
    return line.contains('TPD/');
  }

  static bool _isWeightedLine(String line) {
    return RegExp(
          r'\b\d+(?:\.\d+)?\s*(KG|LB|LBS)\b',
          caseSensitive: false,
        ).hasMatch(line) ||
        line.contains('/KG') ||
        line.contains('/LB');
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

  static bool _looksLikeSplitItemName(String line) {
    final upper = line.toUpperCase();

    if (_extractAmount(line) != null ||
        _looksLikeBarcodeOnly(line) ||
        _looksLikeAddressOrPhone(line) ||
        _isPaymentOrFooterLine(upper) ||
        _isSensitiveLine(upper)) {
      return false;
    }

    if (RegExp(r'^\d{1,2}-[A-Z]').hasMatch(upper)) {
      return false;
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;
    final hasProductCode = RegExp(r'\d{7,14}').hasMatch(line);

    return letterCount >= 3 && hasProductCode;
  }

  static bool _looksLikeStandaloneProductName(String line) {
    final upper = line.toUpperCase();
    final normalizedLabel = _normalizeLabel(line);

    if (_extractAmount(line) != null ||
        _looksLikeBarcodeOnly(line) ||
        _looksLikeAddressOrPhone(line) ||
        _isSensitiveLine(upper) ||
        _isMetadataLine(upper) ||
        _isPaymentOrFooterLine(upper) ||
        _isNonProductLine(upper, normalizedLabel) ||
        _isSubtotalLine(upper, normalizedLabel) ||
        _isTaxLine(upper, normalizedLabel) ||
        _isTotalLine(upper, normalizedLabel)) {
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

    // Avoid treating long numeric transaction or receipt identifiers
    // as product descriptions.
    if (digitCount > letterCount + 4) {
      return false;
    }

    return true;
  }

  static bool _looksLikePriceContinuation(String line) {
    final upper = line.toUpperCase();

    if (_isWeightedLine(upper) && _extractAmount(line) != null) {
      return true;
    }

    return RegExp(
      r'^\s*(?:QTY\s*[:X@]?\s*)?'
      r'\d+(?:\.\d+)?\s*[@X]\s*'
      r'\$?\s*\d+\.\d{2}'
      r'(?:\s+\$?\s*\d+\.\d{2})?'
      r'\s*[A-Z]?\s*$',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static bool _looksLikeQuantityPriceContinuation(String line) {
    final upper = line.toUpperCase();

    if (_extractAmount(line) == null) {
      return false;
    }

    if (_isWeightedLine(upper)) {
      return true;
    }

    final startsWithQuantity = RegExp(
      r'^\s*\(?\s*\d{1,3}\s*\)?\s*'
      r'(?:[@X]|EA\b|FOR\b|/\s*\$?)',
      caseSensitive: false,
    ).hasMatch(line);

    if (startsWithQuantity) {
      return true;
    }

    final hasQuantityMarker = RegExp(
      r'\b(?:QTY|QUANTITY)\b',
      caseSensitive: false,
    ).hasMatch(line);

    if (hasQuantityMarker) {
      return true;
    }

    final amountCount = RegExp(r'\$?\s*\d+\.\d{2}').allMatches(line).length;

    final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;

    // OCR may damage the @ or X character while still preserving both
    // the unit price and line total.
    return amountCount >= 2 && letterCount <= 4;
  }

  static bool _looksLikeAmountOnlyContinuation(String line) {
    if (_extractAmount(line) == null) {
      return false;
    }

    return RegExp(
      r'^\s*'
      r'(?:\$?\s*\d+\.\d{2})'
      r'(?:\s+[A-Z])?'
      r'\s*$',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static bool _isValidItemName(String name) {
    if (name.length < 2) {
      return false;
    }

    final normalized = _normalizeLabel(name);

    if (normalized.isEmpty) {
      return false;
    }

    if (_approximatelyMatches(normalized, 'TOTAL') ||
        _approximatelyMatches(normalized, 'SUBTOTAL') ||
        normalized == 'HST' ||
        normalized == 'GST' ||
        normalized == 'PST' ||
        normalized == 'TAX') {
      return false;
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(name).length;

    return letterCount >= 2;
  }

  static String _detectStoreName(String line) {
    final upper = line.toUpperCase();

    if (upper.contains('WALMART')) return 'Walmart';
    if (upper.contains('COSTCO')) return 'Costco';
    if (upper.contains('NO FRILLS')) return 'No Frills';
    if (upper.contains('FRESHCO')) return 'FreshCo';
    if (upper.contains('FOOD BASICS')) return 'Food Basics';
    if (upper.contains('FOODLAND')) return 'Foodland';
    if (upper.contains('METRO')) return 'Metro';
    if (upper.contains('SOBEYS')) return 'Sobeys';
    if (upper.contains('GIANT TIGER')) return 'Giant Tiger';

    if (upper.contains('INDEPENDENT GROCER') ||
        upper.contains('YOUR INDEPENDENT')) {
      return 'Independent Grocers';
    }

    if (upper.contains('REAL CANADIAN SUPERSTORE')) {
      return 'Real Canadian Superstore';
    }

    if (upper.contains('LOBLAWS')) return 'Loblaws';
    if (upper.contains('ZEHRS')) return 'Zehrs';
    if (upper.contains('VALU-MART') || upper.contains('VALU MART')) {
      return 'Valu-mart';
    }

    return '';
  }

  static DateTime? _detectDate(String line) {
    final yyyyMmDd = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})');

    final mmDdYyyy = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})');

    final first = yyyyMmDd.firstMatch(line);

    if (first != null) {
      return _buildDate(first.group(1), first.group(2), first.group(3));
    }

    final second = mmDdYyyy.firstMatch(line);

    if (second != null) {
      return _buildDate(second.group(3), second.group(1), second.group(2));
    }

    return null;
  }

  static DateTime? _buildDate(
    String? yearText,
    String? monthText,
    String? dayText,
  ) {
    final year = int.tryParse(yearText ?? '');
    final month = int.tryParse(monthText ?? '');
    final day = int.tryParse(dayText ?? '');

    if (year == null || month == null || day == null) {
      return null;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  static double? _extractAmount(String line) {
    final amountRegex = RegExp(
      r'-?\s*\$?\s*'
      r'((?:\d{1,3}(?:,\d{3})*)|\d+)'
      r'\.\d{2}\s*-?',
    );

    final matches = amountRegex.allMatches(line).toList();

    if (matches.isEmpty) {
      return null;
    }

    final raw = matches.last.group(0) ?? '';
    final trimmed = raw.trim();

    final isNegative = trimmed.startsWith('-') || trimmed.endsWith('-');

    final cleaned = trimmed
        .replaceAll('\$', '')
        .replaceAll(',', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');

    final amount = double.tryParse(cleaned);

    if (amount == null) {
      return null;
    }

    return isNegative ? -amount : amount;
  }

  static double? _extractTaxAmount(String line) {
    final amount = _extractAmount(line);

    if (amount == null) {
      return null;
    }

    // Prevent a rate such as "HST 13.00%" from being accepted as a
    // $13.00 tax charge. Receipt-level reconciliation will calculate
    // the actual tax using total minus subtotal.
    final amountText = amount.abs().toStringAsFixed(2);

    final looksLikePercentage = RegExp(
      '${RegExp.escape(amountText)}\\s*%',
      caseSensitive: false,
    ).hasMatch(line);

    if (looksLikePercentage) {
      return null;
    }

    return amount;
  }

  static String _removeAmounts(String line) {
    return line
        .replaceAll(RegExp(r'-?\$?\s*((?:\d{1,3}(?:,\d{3})*)|\d+)\.\d{2}'), '')
        .trim();
  }

  static double _detectQuantity(String line) {
    final kgMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*KG\b',
      caseSensitive: false,
    ).firstMatch(line);

    if (kgMatch != null) {
      return _parsePositiveQuantity(kgMatch.group(1));
    }

    final lbMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*LBS?\b',
      caseSensitive: false,
    ).firstMatch(line);

    if (lbMatch != null) {
      return _parsePositiveQuantity(lbMatch.group(1));
    }
    final parenthesizedQuantityMatch = RegExp(
      r'^\s*\(\s*(\d+(?:\.\d+)?)\s*\)\s*'
      r'(?:[@X]|EA\b)',
      caseSensitive: false,
    ).firstMatch(line);

    if (parenthesizedQuantityMatch != null) {
      return _parsePositiveQuantity(parenthesizedQuantityMatch.group(1));
    }

    final quantityMatch = RegExp(
      r'\bQTY\s*[:X@]?\s*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(line);

    if (quantityMatch != null) {
      return _parsePositiveQuantity(quantityMatch.group(1));
    }

    final multiplicationMatch = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*[X@]\s*\$?\s*\d+\.\d{2}',
      caseSensitive: false,
    ).firstMatch(line);

    if (multiplicationMatch != null) {
      return _parsePositiveQuantity(multiplicationMatch.group(1));
    }

    final multiBuyForMatch = RegExp(
      r'\b(\d+)\s+FOR\s+\$?\s*\d+(?:\.\d{1,2})?',
      caseSensitive: false,
    ).firstMatch(line);

    if (multiBuyForMatch != null) {
      return _parsePositiveQuantity(multiBuyForMatch.group(1));
    }

    final slashDealMatch = RegExp(
      r'\b(\d+)\s*/\s*\$?\s*\d+(?:\.\d{1,2})?',
      caseSensitive: false,
    ).firstMatch(line);

    if (slashDealMatch != null) {
      return _parsePositiveQuantity(slashDealMatch.group(1));
    }

    final buyQuantityMatch = RegExp(
      r'\bBUY\s+(\d+)\b',
      caseSensitive: false,
    ).firstMatch(line);

    if (buyQuantityMatch != null) {
      return _parsePositiveQuantity(buyQuantityMatch.group(1));
    }

    final leadingEachMatch = RegExp(
      r'\b(\d+)\s*EA\b',
      caseSensitive: false,
    ).firstMatch(line);

    if (leadingEachMatch != null) {
      return _parsePositiveQuantity(leadingEachMatch.group(1));
    }

    final trailingEachMatch = RegExp(
      r'\bEA\s*[X@]?\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(line);

    if (trailingEachMatch != null) {
      return _parsePositiveQuantity(trailingEachMatch.group(1));
    }

    return 1;
  }

  static double _parsePositiveQuantity(String? value) {
    final quantity = double.tryParse(value ?? '');

    if (quantity == null || quantity <= 0) {
      return 1;
    }

    return quantity;
  }

  static String _cleanItemName(String name) {
    return name
        .replaceAll(
          RegExp(r'\b\d+(?:\.\d+)?\s*(KG|LB|LBS)\b', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\bQTY\s*[:X@]?\s*\d+(?:\.\d+)?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b\d+\s+FOR\s+\$?\s*\d+(?:\.\d{1,2})?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\b\d+\s*/\s*\$?\s*\d+(?:\.\d{1,2})?', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\bBUY\s+\d+\b', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'\b\d+(?:\.\d+)?\s*[X@]\s*', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\b\d+\s*EA\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bEA\s*[X@]?\s*\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bEA\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bTAX\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[^A-Za-z0-9]+'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9)%]+$'), '')
        .trim();
  }

  static double _confidenceForLine(String line, {required String itemName}) {
    final upper = line.toUpperCase();

    if (_isDiscountLine(upper)) {
      return 60;
    }

    if (_isWeightedLine(upper)) {
      return 88;
    }

    if (itemName.length < 5) {
      return 55;
    }

    if (_extractAmount(line) == null) {
      return 50;
    }

    if (RegExp(r'[A-Za-z]').hasMatch(itemName) &&
        RegExp(r'\d+\.\d{2}').hasMatch(line)) {
      return 80;
    }

    return 70;
  }

  static String _normalizeLabel(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  }

  static bool _approximatelyMatches(String value, String expected) {
    if (value == expected) {
      return true;
    }

    if (value.isEmpty || (value.length - expected.length).abs() > 1) {
      return false;
    }

    return _editDistance(value, expected) <= 1;
  }

  static int _editDistance(String first, String second) {
    final previous = List<int>.generate(second.length + 1, (index) => index);

    for (var firstIndex = 1; firstIndex <= first.length; firstIndex++) {
      final current = List<int>.filled(second.length + 1, 0);
      current[0] = firstIndex;

      for (var secondIndex = 1; secondIndex <= second.length; secondIndex++) {
        final insertion = current[secondIndex - 1] + 1;
        final deletion = previous[secondIndex] + 1;

        final substitution =
            previous[secondIndex - 1] +
            (first[firstIndex - 1] == second[secondIndex - 1] ? 0 : 1);

        current[secondIndex] = [
          insertion,
          deletion,
          substitution,
        ].reduce((left, right) => left < right ? left : right);
      }

      for (var index = 0; index < previous.length; index++) {
        previous[index] = current[index];
      }
    }

    return previous[second.length];
  }

  static double _roundCurrency(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}

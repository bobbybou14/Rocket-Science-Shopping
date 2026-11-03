class ParsedReceipt {
  final String storeName;
  final DateTime? purchaseDate;
  final double subtotal;
  final double tax;
  final double total;
  final List<ParsedReceiptItem> items;
  final List<String> ignoredSensitiveLines;
  final List<String> reviewWarnings;
  final bool subtotalWasRecovered;
  final bool totalWasRecovered;

  const ParsedReceipt({
    this.storeName = '',
    this.purchaseDate,
    this.subtotal = 0,
    this.tax = 0,
    this.total = 0,
    this.items = const [],
    this.ignoredSensitiveLines = const [],
    this.reviewWarnings = const [],
    this.subtotalWasRecovered = false,
    this.totalWasRecovered = false,
  });
}

class ParsedReceiptItem {
  final String name;
  final double price;
  final double quantity;
  final double confidenceScore;
  final bool isDiscount;
  final bool isWeightedItem;

  // Draft-only: zero is a placeholder, not an observed free price.
  final bool priceNeedsReview;
  final String sourceLine;

  const ParsedReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.confidenceScore = 70,
    this.isDiscount = false,
    this.isWeightedItem = false,
    this.priceNeedsReview = false,
    this.sourceLine = '',
  });
}

class ReceiptParserService {
  const ReceiptParserService._();

  static ParsedReceipt parse(String rawText) {
    final lines = _cleanLines(rawText);

    final ignoredSensitiveLines = <String>[];
    final items = <ParsedReceiptItem>[];

    String storeName = _detectStoreName(lines.take(6).join(' '));
    DateTime? purchaseDate;
    double subtotal = 0;
    double tax = 0;
    double total = 0;
    bool hasTaxAmount = false;
    double? damagedSubtotal;
    double? damagedTotal;
    bool subtotalWasRecovered = false;
    bool totalWasRecovered = false;
    final paymentAmounts = <double>[];
    final reviewWarnings = <String>[];

    bool totalsSectionStarted = false;
    bool productSectionClosed = false;
    String? pendingItemName;
    bool awaitingTotalAmount = false;

    for (final line in lines) {
      final upper = line.toUpperCase();
      final normalizedLabel = _normalizeLabel(line);

      // A separate total value must immediately follow its heading. Do not
      // search later footer lines where card identifiers may occur.
      if (awaitingTotalAmount) {
        awaitingTotalAmount = false;
        if (RegExp(r'^\$?\s*\d+\.\d{2}$').hasMatch(line.trim())) {
          total = _extractAmount(line)!.abs();
          continue;
        }
      }

      // Capture only an explicitly labelled payment amount, never card IDs.
      if (totalsSectionStarted || productSectionClosed) {
        final payment = _extractPaymentAmount(line);
        if (payment != null) paymentAmounts.add(payment);
      }

      if (_isSensitiveLine(upper)) {
        ignoredSensitiveLines.add(line);
        continue;
      }

      // Tax-registration headers are metadata, not tax charges.
      final isTaxRegistrationHeader = RegExp(
        r'\b(?:HST|GST|PST|QST)\s*#',
      ).hasMatch(upper);

      // Summary savings are informational, not purchased items
      // or additional discounts to subtract.
      final isSavingsSummary =
          normalizedLabel.contains('YOURSAVINGSTODAY') ||
          normalizedLabel.startsWith('PROMOTIONALDISCOUNTS') ||
          normalizedLabel.startsWith('TOTALOFYOURSAVINGS');

      if (_isMetadataLine(upper) ||
          isTaxRegistrationHeader ||
          isSavingsSummary) {
        pendingItemName = null;
        continue;
      }

      // A standalone savings annotation is informational.
      // Do not subtract it again or send it to product matching.
      // Leave multi-amount lines untouched for separate handling.
      final isSavingsAnnotation = RegExp(
        r'^SAVINGS?\s+\$?\s*\d+\.\d{2}\s*$',
        caseSensitive: false,
      ).hasMatch(line);

      if (isSavingsAnnotation) {
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
        } else {
          damagedSubtotal = _extractDamagedSummaryAmount(line);
        }

        totalsSectionStarted = true;
        pendingItemName = null;
        continue;
      }

      if (_isTaxLine(upper, normalizedLabel)) {
        final amount = _extractTaxAmount(line);

        if (amount != null) {
          tax += amount.abs();
          hasTaxAmount = true;
        }

        totalsSectionStarted = true;
        pendingItemName = null;
        continue;
      }

      if (_isTotalLine(upper, normalizedLabel)) {
        productSectionClosed = true;
        final amount = _extractAmount(line);

        if (amount != null) {
          total = amount.abs();
        } else {
          damagedTotal = _extractDamagedSummaryAmount(line) ?? damagedTotal;
          awaitingTotalAmount = RegExp(
            r'^(?:GRAND\s+TOTAL|TOTAL(?:\s+DUE)?|AMOUNT\s+DUE)\s*[:=]?$',
            caseSensitive: false,
          ).hasMatch(line.trim());
        }

        totalsSectionStarted = true;
        pendingItemName = null;
        continue;
      }

      if (_isPaymentOrFooterLine(upper)) {
        productSectionClosed = true;
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

      if (productSectionClosed ||
          (totalsSectionStarted && !_isDiscountLine(upper))) {
        pendingItemName = null;
        continue;
      }

      // An advertised alternative price is not a purchased line. Keep the
      // pending product for its following quantity/actual-price line.
      if (_isOfferAnnotation(line)) continue;

      // A product-coded line ending in spaced dollars/cents is ambiguous.
      // Retain the row for review rather than losing it or inventing a price.
      final spacedPrice = RegExp(
        r'^(.*[A-Za-z].*?)\s+\d{1,4}\s+\d{2}$',
      ).firstMatch(line);
      if (spacedPrice != null &&
          _extractAmount(line) == null &&
          RegExp(r'\b\d{7,14}\b').hasMatch(spacedPrice.group(1)!)) {
        final name = _cleanItemName(spacedPrice.group(1)!);
        if (_isValidItemName(name)) {
          items.add(
            ParsedReceiptItem(
              name: name,
              price: 0,
              quantity: _quantityFromName(name),
              confidenceScore: 0,
              priceNeedsReview: true,
              sourceLine: line,
            ),
          );
          reviewWarnings.add('A price has ambiguous spacing: $name.');
        }
        pendingItemName = null;
        continue;
      }

      // Preserve a product with a visibly incomplete price such as ".98".
      // Do not invent its dollars or treat it as a valid 0.98 price.
      final incompletePrice = RegExp(
        r'^(.*[A-Za-z].*?)\s+\$?\s*(\.\d{2})(?:\s+[A-Z])?$',
      ).firstMatch(line);

      if (!totalsSectionStarted && incompletePrice != null) {
        final name = _cleanItemName(incompletePrice.group(1)!);
        if (_isValidItemName(name)) {
          items.add(
            ParsedReceiptItem(
              name: name,
              price: 0,
              quantity: _quantityFromName(name),
              confidenceScore: 0,
              priceNeedsReview: true,
              sourceLine: line,
            ),
          );
          reviewWarnings.add('A price is incomplete: $name.');
        }
        pendingItemName = null;
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

      var quantity = _detectQuantity(line);

      if (quantity == 1) {
        quantity = _quantityFromName(name);
      }
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
            priceNeedsReview: previousItem.priceNeedsReview,
            sourceLine: previousItem.sourceLine,
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
          sourceLine: line,
        ),
      );
    }

    // Repair damaged summary punctuation only with independent support.
    // Item amounts are never adjusted to force the receipt to balance.
    final possibleSubtotal = subtotal > 0 ? subtotal : damagedSubtotal;
    final possibleTotal = total > 0 ? total : damagedTotal;

    if (hasTaxAmount &&
        possibleSubtotal != null &&
        possibleSubtotal > 0 &&
        possibleTotal != null &&
        possibleTotal > 0 &&
        _sameMoney(possibleSubtotal + tax, possibleTotal)) {
      final corroborated =
          subtotal > 0 ||
          total > 0 ||
          paymentAmounts.any((amount) => _sameMoney(amount, possibleTotal));
      if (corroborated) {
        if (subtotal == 0) {
          subtotal = possibleSubtotal;
          subtotalWasRecovered = true;
          reviewWarnings.add(
            'Subtotal punctuation recovered using total and tax.',
          );
        }
        if (total == 0) {
          total = possibleTotal;
          totalWasRecovered = true;
          reviewWarnings.add(
            'Total punctuation recovered using subtotal and tax.',
          );
        }
      }
    }

    if (total == 0 && subtotal > 0 && hasTaxAmount) {
      final expected = _roundCurrency(subtotal + tax);
      if (paymentAmounts.any((amount) => _sameMoney(amount, expected))) {
        total = expected;
        totalWasRecovered = true;
        reviewWarnings.add('Total recovered from a matching payment amount.');
      }
    }

    if (subtotal == 0 && total > 0 && hasTaxAmount && total > tax) {
      // Use independent receipt figures, not the possibly incomplete item sum.
      subtotal = _roundCurrency(total - tax);
      subtotalWasRecovered = true;
      reviewWarnings.add('Subtotal calculated from receipt total minus tax.');
    }

    if (!hasTaxAmount && subtotal > 0 && total >= subtotal) {
      tax = _roundCurrency(total - subtotal);
      reviewWarnings.add('Tax calculated from receipt total minus subtotal.');
    }

    if (subtotal > 0 && total > 0 && !_sameMoney(subtotal + tax, total)) {
      reviewWarnings.add('Receipt subtotal, tax, and total do not reconcile.');
    }

    final itemSum = items.fold<double>(0, (sum, item) => sum + item.price);
    if (subtotal > 0 && !_sameMoney(itemSum, subtotal)) {
      reviewWarnings.add('Item amounts do not match the receipt subtotal.');
    }

    return ParsedReceipt(
      storeName: storeName,
      purchaseDate: purchaseDate,
      subtotal: _roundCurrency(subtotal),
      tax: _roundCurrency(tax),
      total: _roundCurrency(total),
      items: items,
      ignoredSensitiveLines: ignoredSensitiveLines,
      reviewWarnings: reviewWarnings,
      subtotalWasRecovered: subtotalWasRecovered,
      totalWasRecovered: totalWasRecovered,
    );
  }

  static bool _sameMoney(double first, double second) {
    return (first * 100).round() == (second * 100).round();
  }

  static bool _isOfferAnnotation(String line) {
    return RegExp(
      r'^\s*\$?\s*\d+\.\d{2}\s*(?:EA|EACH|EN)\s+OR\s+'
      r'\d+\s*/\s*[$S]?\s*\d+\.\d{2}(?:\s+.*)?$',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static double _quantityFromName(String name) {
    final match = RegExp(
      r'^\s*\(?\s*(\d{1,3})\s*[)>]\s*'
      r'(?=(?:\d{8,14}\s+)?[A-Za-z])',
    ).firstMatch(name);

    return match == null ? 1 : _parsePositiveQuantity(match.group(1));
  }

  static double? _extractDamagedSummaryAmount(String line) {
    // Called only on subtotal/total labels. Never applied to item prices,
    // dates, or identifiers. Acceptance also requires corroboration above.
    final match = RegExp(
      r'(?:^|\s)(\d+)(?:\s*[.\-]\s*|\s+)([0-9Oo]{2})\s*$',
    ).firstMatch(line);
    if (match == null) return null;
    final cents = match.group(2)!.replaceAll(RegExp('[Oo]'), '0');
    return double.tryParse('${match.group(1)}.$cents');
  }

  static double? _extractPaymentAmount(String line) {
    final match = RegExp(
      r'^(?:CREDIT|DEBIT|CASH|VISA|MASTERCARD|PAYMENT)'
      r'(?:\s+(?:CR|DR|R))?\s+(?:CAD\s*)?\$?\s*(\d+\.\d{2})$',
      caseSensitive: false,
    ).firstMatch(line.trim());
    return match == null ? null : double.tryParse(match.group(1)!);
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
    if (_isSubtotalLine(upper, normalizedLabel)) return false;

    // A final-total heading may be followed by an amount, not arbitrary
    // footer words such as "Total number of items" or "Total savings".
    return RegExp(
          r'^(?:GRAND\s+TOTAL|TOTAL(?:\s+DUE)?|AMOUNT\s+DUE)'
          r'(?:\s*[:=]?\s*\$?\s*[0-9Oo][0-9Oo.,\s-]*)?$',
          caseSensitive: false,
        ).hasMatch(upper.trim()) ||
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

    final independentHeader = RegExp(
      r'\bYOUR\s+([A-Z]+)\s+GROCER\b',
    ).firstMatch(upper);
    if (upper.contains('INDEPENDENT GROCER') ||
        upper.contains('YOUR INDEPENDENT') ||
        (independentHeader != null &&
            _editDistance(independentHeader.group(1)!, 'INDEPENDENT') <= 2)) {
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
      r'(?<![\d.])(\d+)\s*EA\b',
      caseSensitive: false,
    ).firstMatch(line);

    if (leadingEachMatch != null) {
      return _parsePositiveQuantity(leadingEachMatch.group(1));
    }

    final trailingEachMatch = RegExp(
      r'\bEA\s*[X@]?\s*(\d+)(?![\d.])\b',
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

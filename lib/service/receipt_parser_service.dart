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
  static ParsedReceipt parse(String rawText) {
    final lines = _cleanLines(rawText);

    final ignoredSensitiveLines = <String>[];
    final items = <ParsedReceiptItem>[];

    String storeName = '';
    DateTime? purchaseDate;
    double subtotal = 0;
    double tax = 0;
    double total = 0;

    for (final line in lines) {
      final upper = line.toUpperCase();

      if (_isSensitiveLine(upper)) {
        ignoredSensitiveLines.add(line);
        continue;
      }

      if (storeName.isEmpty) {
        storeName = _detectStoreName(line);
      }

      purchaseDate ??= _detectDate(line);

      final amount = _extractAmount(line);
      if (amount == null) continue;

      if (_isSubtotalLine(upper)) {
        subtotal = amount;
        continue;
      }

      if (_isTaxLine(upper)) {
        tax += amount;
        continue;
      }

      if (_isTotalLine(upper)) {
        total = amount;
        continue;
      }

      if (_isNonProductLine(upper)) continue;

      final name = _cleanItemName(_removeAmount(line));

      if (name.length < 2) continue;

      items.add(
        ParsedReceiptItem(
          name: name,
          price: amount,
          quantity: _detectQuantity(line),
          confidenceScore: _confidenceForLine(line),
          isDiscount: _isDiscountLine(upper),
          isWeightedItem: _isWeightedLine(upper),
        ),
      );
    }

    return ParsedReceipt(
      storeName: storeName,
      purchaseDate: purchaseDate,
      subtotal: subtotal,
      tax: tax,
      total: total,
      items: items,
      ignoredSensitiveLines: ignoredSensitiveLines,
    );
  }

  static List<String> _cleanLines(String rawText) {
    return rawText
        .split('\n')
        .map((line) => line.trim())
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

  static bool _isSubtotalLine(String line) {
    return line.contains('SUBTOTAL') || line.contains('SUB TOTAL');
  }

  static bool _isTaxLine(String line) {
    return line.contains('HST') ||
        line.contains('GST') ||
        line.contains('PST') ||
        line.contains('TAX');
  }

  static bool _isTotalLine(String line) {
    return line == 'TOTAL' ||
        line.startsWith('TOTAL ') ||
        line.contains('AMOUNT DUE') ||
        line.contains('TOTAL DUE');
  }

  static bool _isNonProductLine(String line) {
    return line.contains('CHANGE') ||
        line.contains('BALANCE') ||
        line.contains('CASH') ||
        line.contains('PAYMENT') ||
        line.contains('TENDER') ||
        line.contains('RECEIPT') ||
        line.contains('INVOICE') ||
        line.contains('THANK YOU') ||
        line.contains('SAVE') ||
        line.contains('POINTS');
  }

  static bool _isDiscountLine(String line) {
    return line.contains('DISCOUNT') ||
        line.contains('COUPON') ||
        line.contains('SAVINGS') ||
        line.contains('MULTIBUY') ||
        line.contains('MULTI BUY') ||
        line.contains('PRICE MATCH');
  }

  static bool _isWeightedLine(String line) {
    return line.contains('KG') || line.contains('LB') || line.contains('/KG');
  }

  static String _detectStoreName(String line) {
    final upper = line.toUpperCase();

    if (upper.contains('WALMART')) return 'Walmart';
    if (upper.contains('COSTCO')) return 'Costco';
    if (upper.contains('NO FRILLS')) return 'No Frills';
    if (upper.contains('FRESHCO')) return 'FreshCo';
    if (upper.contains('FOOD BASICS')) return 'Food Basics';
    if (upper.contains('METRO')) return 'Metro';
    if (upper.contains('SOBEYS')) return 'Sobeys';
    if (upper.contains('GIANT TIGER')) return 'Giant Tiger';
    if (upper.contains('REAL CANADIAN SUPERSTORE')) {
      return 'Real Canadian Superstore';
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

  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;

  final date = DateTime(year, month, day);

  if (date.year != year ||
      date.month != month ||
      date.day != day) {
    return null;
  }

  return date;
}

  static double? _extractAmount(String line) {
    final amountRegex = RegExp(r'-?\$?\s*((?:\d+)?\.\d{2})');
    final matches = amountRegex.allMatches(line).toList();

    if (matches.isEmpty) return null;

    final raw = matches.last.group(0) ?? '';
    final cleaned = raw.replaceAll('\$', '').replaceAll(' ', '');

    return double.tryParse(cleaned);
  }

  static String _removeAmount(String line) {
    return line.replaceAll(RegExp(r'-?\$?\s*\d+\.\d{2}'), '').trim();
  }

  static double _detectQuantity(String line) {
    final kgMatch = RegExp(r'(\d+\.\d+)\s*KG', caseSensitive: false).firstMatch(line);
    if (kgMatch != null) {
      return double.tryParse(kgMatch.group(1) ?? '') ?? 1;
    }

    final lbMatch = RegExp(r'(\d+\.\d+)\s*LB', caseSensitive: false).firstMatch(line);
    if (lbMatch != null) {
      return double.tryParse(lbMatch.group(1) ?? '') ?? 1;
    }

    final quantityMatch = RegExp(r'QTY\s*(\d+)', caseSensitive: false).firstMatch(line);
    if (quantityMatch != null) {
      return double.tryParse(quantityMatch.group(1) ?? '') ?? 1;
    }

    return 1;
  }

  static String _cleanItemName(String name) {
    return name
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\bEA\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bTAX\b', caseSensitive: false), '')
        .trim();
  }

  static double _confidenceForLine(String line) {
    final upper = line.toUpperCase();

    if (_isDiscountLine(upper)) return 50;
    if (_isWeightedLine(upper)) return 85;
    if (upper.length < 5) return 55;

    return 75;
  }
}
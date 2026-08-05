import '../models/product.dart';
import '../models/product_suggestion.dart';
import 'receipt_line_interpreter_service.dart';

class ProductSuggestionResult {
  final ProductSuggestion suggestion;
  final List<Product> possibleDuplicates;

  const ProductSuggestionResult({
    required this.suggestion,
    this.possibleDuplicates = const [],
  });

  bool get hasPossibleDuplicates => possibleDuplicates.isNotEmpty;
}

class ProductSuggestionService {
  ProductSuggestionService._();

  static ProductSuggestionResult buildSuggestion({
    required String receiptItemName,
    required List<Product> existingProducts,
  }) {
    final normalizedSource = _normalizeWhitespace(receiptItemName);

    final interpreted = ReceiptLineInterpreterService.interpret(
      normalizedSource,
    );

    final barcode = interpreted.barcode;

    final interpretedDescription = _cleanProductName(interpreted.description);

    final fallbackTextWithoutBarcode = _removeBarcode(
      text: normalizedSource,
      barcode: barcode,
    );

    final fallbackName = _cleanProductName(fallbackTextWithoutBarcode);

    final cleanedName = interpretedDescription.isNotEmpty
        ? interpretedDescription
        : fallbackName;

    final brand = interpreted.brand.isNotEmpty
        ? interpreted.brand
        : _detectBrand(cleanedName);

    final category = _suggestCategory('$brand $cleanedName');

    final size = _formatPackageSize(
      quantity: interpreted.packageQuantity,
      unit: interpreted.packageUnit,
    );

    final reasons = <String>[];
    var confidenceScore = 0.0;

    if (barcode.isNotEmpty) {
      confidenceScore += 35;
      reasons.add('A likely product barcode was found.');
    }

    if (cleanedName.isNotEmpty) {
      confidenceScore += 30;
      reasons.add('A usable product name was extracted.');
    }

    if (brand.isNotEmpty) {
      confidenceScore += 20;
      reasons.add('A likely brand was identified.');
    }

    if (category.isNotEmpty) {
      confidenceScore += 15;
      reasons.add('A likely product category was identified.');
    }

    if (size.isNotEmpty) {
      confidenceScore += 10;
      reasons.add('Package information was identified.');
    }

    final suggestion = ProductSuggestion(
      sourceReceiptName: receiptItemName,
      barcode: barcode,
      name: cleanedName,
      brand: brand,
      category: category,
      size: size,
      confidenceScore: confidenceScore.clamp(0, 100).toDouble(),
      reasons: reasons,
    );

    final possibleDuplicates = _findPossibleDuplicates(
      suggestion: suggestion,
      existingProducts: existingProducts,
    );

    return ProductSuggestionResult(
      suggestion: suggestion,
      possibleDuplicates: possibleDuplicates,
    );
  }

  static String _formatPackageSize({
    required double? quantity,
    required String unit,
  }) {
    if (quantity == null || unit.trim().isEmpty) {
      return '';
    }

    final quantityText = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();

    final normalizedUnit = unit.trim().toUpperCase();

    switch (normalizedUnit) {
      case 'PK':
      case 'PACK':
        return '$quantityText pack';

      case 'CT':
      case 'COUNT':
        return '$quantityText count';

      case 'EA':
      case 'EACH':
        return '$quantityText each';

      case 'GAL':
        return '$quantityText gal';

      case 'ML':
        return '$quantityText mL';

      case 'KG':
        return '$quantityText kg';

      case 'LB':
        return '$quantityText lb';

      case 'OZ':
        return '$quantityText oz';

      case 'L':
      case 'G':
        return '$quantityText $normalizedUnit';

      default:
        return '$quantityText $normalizedUnit';
    }
  }

  static String _removeBarcode({
    required String text,
    required String barcode,
  }) {
    if (barcode.isEmpty) {
      return text;
    }

    return _normalizeWhitespace(
      text.replaceFirst(RegExp('\\b${RegExp.escape(barcode)}\\b'), ''),
    );
  }

  static String _cleanProductName(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'[^\p{L}\p{N}&%+\- ]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final tokens = cleaned.split(' ');

    while (tokens.isNotEmpty && _isNoiseToken(tokens.first)) {
      tokens.removeAt(0);
    }

    while (tokens.isNotEmpty && _isNoiseToken(tokens.last)) {
      tokens.removeLast();
    }

    cleaned = tokens.join(' ').trim();

    if (cleaned.isEmpty) {
      return '';
    }

    return cleaned.split(' ').map(_formatToken).join(' ');
  }

  static bool _isNoiseToken(String token) {
    final normalized = token.toUpperCase();

    if (normalized.isEmpty) {
      return true;
    }

    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return true;
    }

    return _noiseTokens.contains(normalized);
  }

  static String _formatToken(String token) {
    if (token.isEmpty) {
      return token;
    }

    final upper = token.toUpperCase();

    if (_preservedUppercaseTokens.contains(upper)) {
      return upper;
    }

    final lower = token.toLowerCase();

    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  static String _detectBrand(String productName) {
    final upperName = productName.toUpperCase();

    for (final brand in _knownBrands) {
      if (upperName.contains(brand.toUpperCase())) {
        return brand;
      }
    }

    return '';
  }

  static String _suggestCategory(String productName) {
    final upperName = productName.toUpperCase();

    for (final entry in _categoryKeywords.entries) {
      if (entry.value.any(upperName.contains)) {
        return entry.key;
      }
    }

    return '';
  }

  static List<Product> _findPossibleDuplicates({
    required ProductSuggestion suggestion,
    required List<Product> existingProducts,
  }) {
    final normalizedBarcode = suggestion.barcode.trim();
    final normalizedName = _normalizeComparable(suggestion.name);
    final normalizedBrand = _normalizeComparable(suggestion.brand);

    return existingProducts.where((product) {
      if (normalizedBarcode.isNotEmpty &&
          product.barcode.trim() == normalizedBarcode) {
        return true;
      }

      final productName = _normalizeComparable(product.name);
      final productBrand = _normalizeComparable(product.brand);

      if (normalizedName.isEmpty || productName.isEmpty) {
        return false;
      }

      final exactNameMatch = normalizedName == productName;
      final exactBrandMatch =
          normalizedBrand.isEmpty ||
          productBrand.isEmpty ||
          normalizedBrand == productBrand;

      if (exactNameMatch && exactBrandMatch) {
        return true;
      }

      final suggestionTokens = normalizedName.split(' ').toSet();
      final productTokens = productName.split(' ').toSet();

      if (suggestionTokens.isEmpty || productTokens.isEmpty) {
        return false;
      }

      final sharedTokens = suggestionTokens.intersection(productTokens).length;
      final smallerTokenCount = suggestionTokens.length < productTokens.length
          ? suggestionTokens.length
          : productTokens.length;

      final coverage = sharedTokens / smallerTokenCount;

      return coverage >= 0.8 && exactBrandMatch;
    }).toList();
  }

  static String _normalizeComparable(String value) {
    return value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const Set<String> _noiseTokens = {
    'EA',
    'EACH',
    'MRD',
    'HAJ',
    'MRS',
    'OS',
    'PRNIZ',
    'CGOSSRISOORA',
  };

  static const Set<String> _preservedUppercaseTokens = {
    'BBQ',
    'DNA',
    'PC',
    'NN',
    'UPC',
  };

  static const List<String> _knownBrands = [
    'McCain',
    'Drumstick',
    'Wonder',
    'Coca-Cola',
    'Red Bull',
    'No Name',
    'President\'s Choice',
    'Kraft',
    'Heinz',
    'Nestle',
    'Black Diamond',
    'Maple Leaf',
    'Neilson',
    'Astro',
    'Catelli',
    'Doritos',
    'Ritz',
  ];

  static const Map<String, List<String>> _categoryKeywords = {
    'Frozen Food': [
      'MCCAIN',
      'DRUMSTICK',
      'FROZEN',
      'ICE CREAM',
      'PIZZA',
      'FROZEN DINNER',
    ],
    'Bakery': [
      'BREAD',
      'BUN',
      'BAGEL',
      'MUFFIN',
      'TORTILLA',
      'ROLL',
      'CROISSANT',
    ],
    'Dairy': [
      'CHEESE',
      'MILK',
      'YOGURT',
      'CREAM',
      'BUTTER',
      'MOZZARELLA',
      'CHEDDAR',
      'SHREDDED',
    ],
    'Beverages': [
      'COLA',
      'WATER',
      'ENERGY',
      'JUICE',
      'DRINK',
      'COFFEE',
      'TEA',
      'SODA',
      'PEPPER',
    ],
    'Meat': [
      'CHICKEN',
      'BEEF',
      'PORK',
      'TURKEY',
      'BACON',
      'SAUSAGE',
      'GROUND BEEF',
    ],
    'Produce': [
      'APPLE',
      'BANANA',
      'BANANAS',
      'WATERMELON',
      'BERRY',
      'PUMPKIN',
      'TOMATO',
      'POTATO',
      'CARROT',
      'ONION',
    ],
    'Pantry': [
      'PEANUT BUTTER',
      'MARSHMALLOW',
      'PASTA',
      'RICE',
      'SAUCE',
      'CEREAL',
      'FLOUR',
      'SUGAR',
      'SPICE',
      'KETCHUP',
    ],
    'Snacks': [
      'CHIPS',
      'CHOCOLATE',
      'CANDY',
      'COOKIE',
      'CRACKER',
      'GRANOLA',
      'SNACK',
    ],
    'Household': [
      'PAPER TOWEL',
      'TOILET PAPER',
      'DETERGENT',
      'DISH SOAP',
      'CLEANER',
    ],
  };
}

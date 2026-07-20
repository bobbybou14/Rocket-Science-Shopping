import '../models/product.dart';
import 'receipt_parser_service.dart';

class ProductMatchResult {
  final ParsedReceiptItem receiptItem;
  final Product? product;
  final double confidenceScore;
  final String reason;

  const ProductMatchResult({
    required this.receiptItem,
    required this.product,
    required this.confidenceScore,
    required this.reason,
  });

  bool get hasMatch => product != null;
}

class ProductMatcherService {
  static List<ProductMatchResult> matchItems({
    required List<ParsedReceiptItem> receiptItems,
    required List<Product> products,
  }) {
    return receiptItems.map((item) {
      return matchItem(
        receiptItem: item,
        products: products,
      );
    }).toList();
  }

  static ProductMatchResult matchItem({
    required ParsedReceiptItem receiptItem,
    required List<Product> products,
  }) {
    Product? bestProduct;
    double bestScore = 0;

    for (final product in products) {
      final score = _scoreMatch(receiptItem.name, product);

      if (score > bestScore) {
        bestScore = score;
        bestProduct = product;
      }
    }

    if (bestProduct == null || bestScore < 45) {
      return ProductMatchResult(
        receiptItem: receiptItem,
        product: null,
        confidenceScore: bestScore,
        reason: 'No reliable product match found.',
      );
    }

    return ProductMatchResult(
      receiptItem: receiptItem,
      product: bestProduct,
      confidenceScore: bestScore,
      reason: _reasonForScore(bestScore),
    );
  }

  static double _scoreMatch(String receiptText, Product product) {
    final receiptTokens = _tokens(receiptText);
    final productTokens = _tokens(
      '${product.brand} ${product.name} ${product.category} ${product.size}',
    );

    if (receiptTokens.isEmpty || productTokens.isEmpty) return 0;

    double score = 0;

    for (final receiptToken in receiptTokens) {
      for (final productToken in productTokens) {
        score += _tokenScore(receiptToken, productToken);
      }
    }

    final maxPossibleScore = receiptTokens.length * 100;
    final normalizedScore = (score / maxPossibleScore) * 100;

    final categoryBonus = _categoryBonus(receiptTokens, product);
    final sizeBonus = _sizeBonus(receiptText, product);

    return (normalizedScore + categoryBonus + sizeBonus).clamp(0, 100);
  }

  static double _tokenScore(String receiptToken, String productToken) {
    if (receiptToken == productToken) return 100;

    if (receiptToken.startsWith(productToken) && productToken.length >= 3) {
      return 75;
    }

    if (productToken.startsWith(receiptToken) && receiptToken.length >= 3) {
      return 75;
    }

    if (receiptToken.contains(productToken) && productToken.length >= 3) {
      return 60;
    }

    if (productToken.contains(receiptToken) && receiptToken.length >= 3) {
      return 60;
    }

    return 0;
  }

  static List<String> _tokens(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .map(_normalizeToken)
      .where((token) => token.length >= 2)
      .toSet()
      .toList();
}

  static String _normalizeToken(String token) {
    final normalized = token.trim().toUpperCase();

    const replacements = {
      'WHT': 'WHITE',
      'BRD': 'BREAD',
      'MLK': 'MILK',
      'HOMO': 'MILK',
      'HOMOGENIZED': 'MILK',
      'CHOC': 'CHOCOLATE',
      'BNNS': 'BANANAS',
      'BAN': 'BANANAS',
      'ORG': 'ORGANIC',
      'GRN': 'GREEN',
      'TOM': 'TOMATOES',
      'POT': 'POTATOES',
      'YOG': 'YOGURT',
      'CHKN': 'CHICKEN',
      'CHK': 'CHICKEN',
    };

    return replacements[normalized] ?? normalized;
  }

  static double _categoryBonus(List<String> receiptTokens, Product product) {
    final category = product.category.toUpperCase();

    if (category == 'DAIRY' && receiptTokens.contains('MILK')) return 20;
    if (category == 'BAKERY' && receiptTokens.contains('BREAD')) return 20;
    if (category == 'PRODUCE' &&
        (receiptTokens.contains('BANANAS') ||
            receiptTokens.contains('TOMATOES') ||
            receiptTokens.contains('POTATOES'))) {
      return 20;
    }

    return 0;
  }

  static double _sizeBonus(String receiptText, Product product) {
    final receipt = receiptText.toUpperCase().replaceAll(' ', '');
    final size = product.size.toUpperCase().replaceAll(' ', '');

    if (size.isEmpty) return 0;
    if (receipt.contains(size)) return 10;

    return 0;
  }

  static String _reasonForScore(double score) {
    if (score >= 90) return 'Very strong match.';
    if (score >= 75) return 'Good match.';
    if (score >= 55) return 'Possible match. Review recommended.';

    return 'Low confidence match.';
  }
}
import '../models/product.dart';
import 'receipt_cleanup_service.dart';
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
    final matches = receiptItems.map((item) {
      return matchItem(receiptItem: item, products: products);
    }).toList();

    assert(() {
      // ignore: avoid_print
      print('----- PRODUCT MATCHES START -----');

      // ignore: avoid_print
      print('Receipt item count: ${receiptItems.length}');

      // ignore: avoid_print
      print('Available product count: ${products.length}');

      if (matches.isEmpty) {
        // ignore: avoid_print
        print('No receipt items were sent to the product matcher.');
      }

      for (var index = 0; index < matches.length; index++) {
        final result = matches[index];
        final product = result.product;

        final matchedName = product == null
            ? 'NO MATCH'
            : [
                product.brand,
                product.name,
                product.size,
              ].where((part) => part.trim().isNotEmpty).join(' ');

        // ignore: avoid_print
        print('MATCH ${index + 1}');

        // ignore: avoid_print
        print('  OCR: ${result.receiptItem.name}');

        // ignore: avoid_print
        print('  PRODUCT: $matchedName');

        // ignore: avoid_print
        print('  SCORE: ${result.confidenceScore.toStringAsFixed(1)}');

        // ignore: avoid_print
        print('  REASON: ${result.reason}');
      }

      // ignore: avoid_print
      print('----- PRODUCT MATCHES END -----');

      return true;
    }());

    return matches;
  }

  static ProductMatchResult matchItem({
    required ParsedReceiptItem receiptItem,
    required List<Product> products,
  }) {
    final receiptBarcode = _extractBarcode(receiptItem.name);

    if (receiptBarcode.isNotEmpty) {
      for (final product in products) {
        if (_barcodesMatch(product.barcode, receiptBarcode)) {
          return ProductMatchResult(
            receiptItem: receiptItem,
            product: product,
            confidenceScore: 100,
            reason: 'Exact barcode match.',
          );
        }
      }
    }

    Product? bestProduct;
    double bestScore = 0;

    for (final product in products) {
      final score = _scoreMatch(receiptItem.name, product);

      if (score > bestScore) {
        bestScore = score;
        bestProduct = product;
      }
    }

    if (bestProduct == null || bestScore < 60) {
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

  static List<ProductMatchResult> suggestMatches({
    required ParsedReceiptItem receiptItem,
    required List<Product> products,
    int limit = 5,
    double minimumScore = 20,
  }) {
    if (limit <= 0 || products.isEmpty) {
      return const [];
    }

    final suggestions =
        products
            .map((product) {
              final score = _scoreMatch(receiptItem.name, product);

              return ProductMatchResult(
                receiptItem: receiptItem,
                product: product,
                confidenceScore: score,
                reason: _reasonForScore(score),
              );
            })
            .where((result) => result.confidenceScore >= minimumScore)
            .toList()
          ..sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

    return suggestions.take(limit).toList();
  }

  static double _scoreMatch(String receiptText, Product product) {
    final cleanedReceiptText = ReceiptCleanupService.clean(receiptText);
    final receiptTokens = _tokens(cleanedReceiptText);

    // Category is intentionally excluded from the primary token comparison.
    // Otherwise generic values such as "BAKERY" or "DAIRY" can inflate an
    // otherwise weak product-name match.
    final productTokens = _tokens('${product.brand} ${product.name}');

    if (receiptTokens.isEmpty || productTokens.isEmpty) {
      return 0;
    }

    var totalBestTokenScore = 0.0;
    var matchedReceiptTokens = 0;
    var strongReceiptTokens = 0;

    for (final receiptToken in receiptTokens) {
      var bestTokenScore = 0.0;

      for (final productToken in productTokens) {
        final tokenScore = _tokenScore(receiptToken, productToken);

        if (tokenScore > bestTokenScore) {
          bestTokenScore = tokenScore;
        }
      }

      totalBestTokenScore += bestTokenScore;

      if (bestTokenScore >= 55) {
        matchedReceiptTokens++;
      }

      if (bestTokenScore >= 75) {
        strongReceiptTokens++;
      }
    }

    final averageTokenScore = totalBestTokenScore / receiptTokens.length;

    final receiptCoverage = (matchedReceiptTokens / receiptTokens.length) * 100;

    final strongCoverage = (strongReceiptTokens / receiptTokens.length) * 100;

    var score =
        (averageTokenScore * 0.65) +
        (receiptCoverage * 0.20) +
        (strongCoverage * 0.15);

    score += _wholeTextBonus(receiptText: cleanedReceiptText, product: product);

    score += _categoryBonus(receiptTokens, product);
    score += _sizeBonus(cleanedReceiptText, product);

    return score.clamp(0, 100).toDouble();
  }

  static double _tokenScore(String receiptToken, String productToken) {
    final weight = _tokenWeight(receiptToken);

    if (receiptToken == productToken) {
      return 100 * weight;
    }

    if (receiptToken.length >= 3 && productToken.length >= 3) {
      final shorterLength = receiptToken.length < productToken.length
          ? receiptToken.length
          : productToken.length;

      final lengthDifference = (receiptToken.length - productToken.length)
          .abs();

      // Prefix matches are useful for receipt abbreviations such as
      // WHIP → WHIPPING or TORT → TORTILLA, but very short tokens such as
      // BAG must not create strong matches with unrelated words like BAGEL.
      if (shorterLength >= 4 &&
          lengthDifference <= 4 &&
          (receiptToken.startsWith(productToken) ||
              productToken.startsWith(receiptToken))) {
        return 85 * weight;
      }

      // Substring matches require more evidence than prefix matches.
      if (shorterLength >= 5 &&
          lengthDifference <= 4 &&
          (receiptToken.contains(productToken) ||
              productToken.contains(receiptToken))) {
        return 75 * weight;
      }
    }

    if (receiptToken.length < 3 || productToken.length < 3) {
      return 0;
    }

    final similarity = _editSimilarity(receiptToken, productToken);

    if (similarity >= 0.90) {
      return 90 * weight;
    }

    if (similarity >= 0.80) {
      return 82 * weight;
    }

    if (similarity >= 0.70) {
      return 70 * weight;
    }

    if (similarity >= 0.60 &&
        receiptToken.length >= 4 &&
        productToken.length >= 4) {
      return 55 * weight;
    }

    return 0;
  }

  static double _tokenWeight(String token) {
    switch (token) {
      // Very common brand words
      case 'GREAT':
      case 'VALUE':
      case 'NO':
      case 'NAME':
        return 0.35;

      // Common descriptors
      case 'ORGANIC':
      case 'NATURAL':
      case 'FRESH':
      case 'PLAIN':
      case 'WHITE':
        return 0.80;

      default:
        return 1.0;
    }
  }

  static double _editSimilarity(String first, String second) {
    if (first == second) {
      return 1;
    }

    if (first.isEmpty || second.isEmpty) {
      return 0;
    }

    final distance = _levenshteinDistance(first, second);
    final longestLength = first.length > second.length
        ? first.length
        : second.length;

    return 1 - (distance / longestLength);
  }

  static int _levenshteinDistance(String first, String second) {
    final previousRow = List<int>.generate(second.length + 1, (index) => index);

    for (var firstIndex = 1; firstIndex <= first.length; firstIndex++) {
      final currentRow = List<int>.filled(second.length + 1, 0);
      currentRow[0] = firstIndex;

      for (var secondIndex = 1; secondIndex <= second.length; secondIndex++) {
        final substitutionCost =
            first[firstIndex - 1] == second[secondIndex - 1] ? 0 : 1;

        final deletion = previousRow[secondIndex] + 1;
        final insertion = currentRow[secondIndex - 1] + 1;
        final substitution = previousRow[secondIndex - 1] + substitutionCost;

        currentRow[secondIndex] = _minimumOfThree(
          deletion,
          insertion,
          substitution,
        );
      }

      for (var index = 0; index < previousRow.length; index++) {
        previousRow[index] = currentRow[index];
      }
    }

    return previousRow[second.length];
  }

  static int _minimumOfThree(int first, int second, int third) {
    var minimum = first;

    if (second < minimum) {
      minimum = second;
    }

    if (third < minimum) {
      minimum = third;
    }

    return minimum;
  }

  static double _wholeTextBonus({
    required String receiptText,
    required Product product,
  }) {
    final normalizedReceipt = _normalizeComparableText(receiptText);
    final normalizedProduct = _normalizeComparableText(
      '${product.brand} ${product.name}',
    );

    if (normalizedReceipt.isEmpty || normalizedProduct.isEmpty) {
      return 0;
    }

    if (normalizedReceipt == normalizedProduct) {
      return 15;
    }

    if (normalizedReceipt.contains(normalizedProduct) ||
        normalizedProduct.contains(normalizedReceipt)) {
      return 8;
    }

    return 0;
  }

  static String _normalizeComparableText(String value) {
    return _tokens(value).join(' ');
  }

  static List<String> _tokens(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .map(_normalizeToken)
        .where((token) => token.length >= 2)
        .where((token) => !_receiptNoiseTokens.contains(token))
        .where((token) => !RegExp(r'^\d{6,14}$').hasMatch(token))
        .toSet()
        .toList();
  }

  static String _extractBarcode(String value) {
    final matches = RegExp(r'\b\d{8,14}\b').allMatches(value);

    for (final match in matches) {
      final barcode = match.group(0);

      if (barcode != null && barcode.isNotEmpty) {
        return _normalizeBarcode(barcode);
      }
    }

    return '';
  }

  static String _normalizeBarcode(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool _barcodesMatch(String first, String second) {
    final firstBarcode = _normalizeBarcode(first);
    final secondBarcode = _normalizeBarcode(second);

    if (firstBarcode.isEmpty || secondBarcode.isEmpty) {
      return false;
    }

    if (firstBarcode == secondBarcode) {
      return true;
    }

    // UPC-A barcodes are often stored as EAN-13 values with a leading zero.
    if (firstBarcode.length == 13 &&
        firstBarcode.startsWith('0') &&
        firstBarcode.substring(1) == secondBarcode) {
      return true;
    }

    if (secondBarcode.length == 13 &&
        secondBarcode.startsWith('0') &&
        secondBarcode.substring(1) == firstBarcode) {
      return true;
    }

    return false;
  }

  static const Set<String> _receiptNoiseTokens = {
    'EA',
    'EACH',
    'HAJ',
    'MRD',
    'MRS',
    'OS',
    'PRNIZ',
    'PTS',
    'POINTS',
    'CGOSSRISOORA',
  };

  static String _normalizeToken(String token) {
    final normalized = token.trim().toUpperCase();

    const replacements = {
      'WHT': 'WHITE',
      'WHI': 'WHITE',
      'WHTE': 'WHITE',

      'BRD': 'BREAD',
      'BRED': 'BREAD',

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

      'CRM': 'CARAMEL',
      'CRML': 'CARAMEL',

      'DRMSTK': 'DRUMSTICK',

      'MCCN': 'MCCAIN',

      'NAT': 'NATURAL',

      'CHS': 'CHEESE',
      'CHSE': 'CHEESE',

      'ENGY': 'ENERGY',
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

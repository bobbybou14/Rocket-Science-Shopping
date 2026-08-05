import 'receipt_cleanup_service.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import 'product_alias_service.dart';
import 'product_matcher_service.dart';
import 'product_service.dart';
import 'product_suggestion_service.dart';
import 'receipt_line_interpreter_service.dart';
import 'receipt_parser_service.dart';

class ReceiptIntelligenceResult {
  final ParsedReceipt parsedReceipt;
  final List<ProductMatchResult> productMatches;
  final List<ProductSuggestionResult> productSuggestions;
  final List<Product> products;
  final int highConfidenceMatches;
  final int reviewRequired;

  const ReceiptIntelligenceResult({
    required this.parsedReceipt,
    required this.productMatches,
    required this.productSuggestions,
    required this.products,
    required this.highConfidenceMatches,
    required this.reviewRequired,
  });

  bool get hasProductSuggestions => productSuggestions.isNotEmpty;
}

class ReceiptIntelligenceService {
  static Future<ReceiptIntelligenceResult> processRawText(
    String rawText,
  ) async {
    final parsedReceipt = ReceiptParserService.parse(rawText);

    final products = await ProductService.getProducts();
    final aliases = await ProductAliasService.getAliases();

    final matches = parsedReceipt.items.map((item) {
      final aliasProduct = ProductAliasService.findMatchingProduct(
        receiptItemName: item.name,
        aliases: aliases,
        products: products,
      );

      if (aliasProduct != null) {
        return ProductMatchResult(
          receiptItem: item,
          product: aliasProduct,
          confidenceScore: 100,
          reason: 'Matched using a learned product alias.',
        );
      }

      return ProductMatcherService.matchItem(
        receiptItem: item,
        products: products,
      );
    }).toList();

    assert(() {
      debugPrint('----- PRODUCT MATCHES START -----');
      debugPrint('Parsed receipt item count: ${parsedReceipt.items.length}');
      debugPrint('Available product count: ${products.length}');
      debugPrint('Available alias count: ${aliases.length}');

      if (matches.isEmpty) {
        debugPrint('No parsed receipt items were available for matching.');
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

        final cleaned = ReceiptCleanupService.clean(result.receiptItem.name);

        final interpreted = ReceiptLineInterpreterService.interpret(
          result.receiptItem.name,
        );

        debugPrint('MATCH ${index + 1}');
        debugPrint('  OCR RAW: ${result.receiptItem.name}');
        debugPrint('  OCR CLEANED: $cleaned');
        debugPrint('  INTERPRETED BRAND: ${interpreted.brand}');
        debugPrint('  INTERPRETED DESCRIPTION: ${interpreted.description}');
        debugPrint(
          '  INTERPRETED PACKAGE: '
          '${interpreted.packageQuantity ?? ''} '
          '${interpreted.packageUnit}',
        );

        if (interpreted.barcode.isNotEmpty) {
          debugPrint('  BARCODE: ${interpreted.barcode}');
        }

        debugPrint('  PRODUCT: $matchedName');
        debugPrint('  SCORE: ${result.confidenceScore.toStringAsFixed(1)}');
        debugPrint('  REASON: ${result.reason}');
      }

      debugPrint('----- PRODUCT MATCHES END -----');

      return true;
    }());

    final productSuggestions = matches
        .where((match) => !match.hasMatch)
        .map(
          (match) => ProductSuggestionService.buildSuggestion(
            receiptItemName: match.receiptItem.name,
            existingProducts: products,
          ),
        )
        .toList();

    assert(() {
      debugPrint('----- PRODUCT SUGGESTIONS START -----');
      debugPrint(
        'Unmatched product suggestion count: ${productSuggestions.length}',
      );

      for (var index = 0; index < productSuggestions.length; index++) {
        final result = productSuggestions[index];
        final suggestion = result.suggestion;

        debugPrint('SUGGESTION ${index + 1}');
        debugPrint('  SOURCE: ${suggestion.sourceReceiptName}');
        debugPrint('  NAME: ${suggestion.name}');
        debugPrint('  BRAND: ${suggestion.brand}');
        debugPrint('  CATEGORY: ${suggestion.category}');
        debugPrint('  BARCODE: ${suggestion.barcode}');
        debugPrint(
          '  CONFIDENCE: ${suggestion.confidenceScore.toStringAsFixed(1)}',
        );
        debugPrint(
          '  POSSIBLE DUPLICATES: ${result.possibleDuplicates.length}',
        );
      }

      debugPrint('----- PRODUCT SUGGESTIONS END -----');

      return true;
    }());

    final highConfidence = matches
        .where((match) => match.hasMatch && match.confidenceScore >= 75)
        .length;

    final needsReview = matches.length - highConfidence;

    return ReceiptIntelligenceResult(
      parsedReceipt: parsedReceipt,
      productMatches: matches,
      productSuggestions: productSuggestions,
      products: products,
      highConfidenceMatches: highConfidence,
      reviewRequired: needsReview,
    );
  }
}

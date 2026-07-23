import '../models/product.dart';
import 'product_matcher_service.dart';
import 'product_service.dart';
import 'receipt_parser_service.dart';

class ReceiptIntelligenceResult {
  final ParsedReceipt parsedReceipt;
  final List<ProductMatchResult> productMatches;
  final int highConfidenceMatches;
  final int reviewRequired;

  const ReceiptIntelligenceResult({
    required this.parsedReceipt,
    required this.productMatches,
    required this.highConfidenceMatches,
    required this.reviewRequired,
  });
}

class ReceiptIntelligenceService {
  static Future<ReceiptIntelligenceResult> processRawText(
    String rawText,
  ) async {
    final parsedReceipt = ReceiptParserService.parse(rawText);
    final List<Product> products = await ProductService.getProducts();

    final matches = ProductMatcherService.matchItems(
      receiptItems: parsedReceipt.items,
      products: products,
    );

    final highConfidence = matches
        .where((match) => match.hasMatch && match.confidenceScore >= 75)
        .length;

    final needsReview = matches.length - highConfidence;

    return ReceiptIntelligenceResult(
      parsedReceipt: parsedReceipt,
      productMatches: matches,
      highConfidenceMatches: highConfidence,
      reviewRequired: needsReview,
    );
  }
}

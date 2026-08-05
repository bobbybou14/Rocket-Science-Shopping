import '../models/product_import_candidate.dart';
import '../models/product_suggestion.dart';
import 'match_quality_service.dart';
import 'product_service.dart';
import 'product_suggestion_service.dart';

class ProductImportCandidateService {
  ProductImportCandidateService._();

  static Future<List<ProductImportCandidate>> getCandidates({
    int limit = 25,
  }) async {
    if (limit <= 0) {
      return const [];
    }

    final summary = await MatchQualityService.getSummary();
    final products = await ProductService.getProducts();

    final candidates = <ProductImportCandidate>[];

    for (final unmatched in summary.commonUnmatchedItems) {
      final suggestionResult = ProductSuggestionService.buildSuggestion(
        receiptItemName: unmatched.receiptName,
        existingProducts: products,
      );

      final ProductSuggestion suggestion = suggestionResult.suggestion;

      candidates.add(
        ProductImportCandidate(
          receiptName: unmatched.receiptName,
          occurrences: unmatched.occurrences,
          suggestedBrand: suggestion.brand,
          suggestedCategory: suggestion.category,
          barcode: suggestion.barcode,
          confidenceScore: suggestion.confidenceScore,
        ),
      );
    }

    candidates.sort((first, second) {
      final priorityComparison = second.priorityScore.compareTo(
        first.priorityScore,
      );

      if (priorityComparison != 0) {
        return priorityComparison;
      }

      final occurrenceComparison = second.occurrences.compareTo(
        first.occurrences,
      );

      if (occurrenceComparison != 0) {
        return occurrenceComparison;
      }

      return first.receiptName.compareTo(second.receiptName);
    });

    return candidates.take(limit).toList();
  }
}

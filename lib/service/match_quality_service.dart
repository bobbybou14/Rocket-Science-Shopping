import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match_quality_summary.dart';

class MatchQualityService {
  MatchQualityService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<MatchQualitySummary> getSummary({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = _client.from('shopping_trip_items').select('''
      raw_receipt_name,
      confidence_score,
      requires_review,
      barcode,
      products (
        barcode
      ),
      shopping_trips (
        store_name,
        purchase_date
      )
    ''');

    if (fromDate != null) {
      query = query.gte(
        'shopping_trips.purchase_date',
        fromDate.toIso8601String(),
      );
    }

    if (toDate != null) {
      query = query.lte(
        'shopping_trips.purchase_date',
        toDate.toIso8601String(),
      );
    }

    final response = await query;

    if (response.isEmpty) {
      return MatchQualitySummary.empty;
    }

    var totalItems = 0;
    var matchedItems = 0;
    var unmatchedItems = 0;
    var reviewItems = 0;

    var highConfidence = 0;
    var mediumConfidence = 0;
    var lowConfidence = 0;

    var confidenceTotal = 0.0;

    final unmatchedCounts = <String, int>{};
    final storeStats = <String, _StoreAccumulator>{};

    for (final row in response) {
      totalItems++;

      final confidence = (row['confidence_score'] as num?)?.toDouble() ?? 0.0;

      confidenceTotal += confidence;

      final requiresReview = row['requires_review'] == true;

      final hasProduct = row['products'] != null;

      if (hasProduct) {
        matchedItems++;
      } else {
        unmatchedItems++;

        final receiptName = (row['raw_receipt_name'] ?? '').toString().trim();

        if (receiptName.isNotEmpty) {
          unmatchedCounts.update(
            receiptName,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }

      if (requiresReview) {
        reviewItems++;
      }

      if (confidence >= 75) {
        highConfidence++;
      } else if (confidence >= 60) {
        mediumConfidence++;
      } else {
        lowConfidence++;
      }

      final trip = row['shopping_trips'] as Map<String, dynamic>?;

      final storeName = trip?['store_name']?.toString() ?? 'Unknown';

      final stats = storeStats.putIfAbsent(
        storeName,
        () => _StoreAccumulator(storeName),
      );

      stats.total++;
      stats.confidence += confidence;

      if (hasProduct) {
        stats.matched++;
      } else {
        stats.unmatched++;
      }

      if (requiresReview) {
        stats.review++;
      }
    }

    final unmatchedList = unmatchedCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final stores = storeStats.values.map((stats) {
      return StoreMatchQualitySummary(
        storeName: stats.storeName,
        totalItems: stats.total,
        matchedItems: stats.matched,
        unmatchedItems: stats.unmatched,
        reviewRequiredItems: stats.review,
        averageConfidence: stats.total == 0
            ? 0
            : stats.confidence / stats.total,
      );
    }).toList()..sort((a, b) => b.totalItems.compareTo(a.totalItems));

    return MatchQualitySummary(
      totalItems: totalItems,
      matchedItems: matchedItems,
      unmatchedItems: unmatchedItems,
      highConfidenceItems: highConfidence,
      mediumConfidenceItems: mediumConfidence,
      lowConfidenceItems: lowConfidence,
      reviewRequiredItems: reviewItems,
      averageConfidence: totalItems == 0 ? 0 : confidenceTotal / totalItems,
      fromDate: fromDate,
      toDate: toDate,
      commonUnmatchedItems: unmatchedList
          .take(10)
          .map(
            (entry) => UnmatchedReceiptItemSummary(
              receiptName: entry.key,
              occurrences: entry.value,
            ),
          )
          .toList(),
      stores: stores,
    );
  }
}

class _StoreAccumulator {
  final String storeName;

  int total = 0;
  int matched = 0;
  int unmatched = 0;
  int review = 0;
  double confidence = 0;

  _StoreAccumulator(this.storeName);
}

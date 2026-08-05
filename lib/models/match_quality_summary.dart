class MatchQualitySummary {
  final int totalItems;
  final int matchedItems;
  final int unmatchedItems;
  final int highConfidenceItems;
  final int mediumConfidenceItems;
  final int lowConfidenceItems;
  final int reviewRequiredItems;
  final double averageConfidence;
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<UnmatchedReceiptItemSummary> commonUnmatchedItems;
  final List<StoreMatchQualitySummary> stores;

  const MatchQualitySummary({
    required this.totalItems,
    required this.matchedItems,
    required this.unmatchedItems,
    required this.highConfidenceItems,
    required this.mediumConfidenceItems,
    required this.lowConfidenceItems,
    required this.reviewRequiredItems,
    required this.averageConfidence,
    this.fromDate,
    this.toDate,
    this.commonUnmatchedItems = const [],
    this.stores = const [],
  });

  static const empty = MatchQualitySummary(
    totalItems: 0,
    matchedItems: 0,
    unmatchedItems: 0,
    highConfidenceItems: 0,
    mediumConfidenceItems: 0,
    lowConfidenceItems: 0,
    reviewRequiredItems: 0,
    averageConfidence: 0,
  );

  double get matchRate {
    if (totalItems == 0) {
      return 0;
    }

    return (matchedItems / totalItems) * 100;
  }

  double get unmatchedRate {
    if (totalItems == 0) {
      return 0;
    }

    return (unmatchedItems / totalItems) * 100;
  }

  double get reviewRate {
    if (totalItems == 0) {
      return 0;
    }

    return (reviewRequiredItems / totalItems) * 100;
  }
}

class UnmatchedReceiptItemSummary {
  final String receiptName;
  final int occurrences;

  const UnmatchedReceiptItemSummary({
    required this.receiptName,
    required this.occurrences,
  });
}

class StoreMatchQualitySummary {
  final String storeName;
  final int totalItems;
  final int matchedItems;
  final int unmatchedItems;
  final int reviewRequiredItems;
  final double averageConfidence;

  const StoreMatchQualitySummary({
    required this.storeName,
    required this.totalItems,
    required this.matchedItems,
    required this.unmatchedItems,
    required this.reviewRequiredItems,
    required this.averageConfidence,
  });

  double get matchRate {
    if (totalItems == 0) {
      return 0;
    }

    return (matchedItems / totalItems) * 100;
  }
}

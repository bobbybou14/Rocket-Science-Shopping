class SavingsHighlight {
  final String productName;
  final String storeName;
  final double amountSaved;
  final double purchasePrice;
  final double comparisonPrice;

  const SavingsHighlight({
    required this.productName,
    required this.storeName,
    required this.amountSaved,
    required this.purchasePrice,
    required this.comparisonPrice,
  });

  bool get hasSavings => amountSaved > 0;
}

class SavingsSummary {
  final double totalSavings;
  final double watchlistSavingsPotential;
  final int priceDropCount;
  final int purchasesCompared;
  final SavingsHighlight? bestDeal;

  const SavingsSummary({
    required this.totalSavings,
    required this.watchlistSavingsPotential,
    required this.priceDropCount,
    required this.purchasesCompared,
    this.bestDeal,
  });

  const SavingsSummary.empty()
    : totalSavings = 0,
      watchlistSavingsPotential = 0,
      priceDropCount = 0,
      purchasesCompared = 0,
      bestDeal = null;

  bool get hasData =>
      purchasesCompared > 0 ||
      priceDropCount > 0 ||
      totalSavings > 0 ||
      watchlistSavingsPotential > 0 ||
      bestDeal != null;

  bool get hasRecordedSavings => totalSavings > 0;

  bool get hasWatchlistPotential => watchlistSavingsPotential > 0;

  bool get hasPriceDrops => priceDropCount > 0;

  String get totalSavingsLabel => '\$${totalSavings.toStringAsFixed(2)}';

  String get watchlistSavingsPotentialLabel =>
      '\$${watchlistSavingsPotential.toStringAsFixed(2)}';
}

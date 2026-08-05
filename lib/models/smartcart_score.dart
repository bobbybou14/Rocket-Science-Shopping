class SmartCartScore {
  final int score;
  final String grade;
  final String title;
  final String summary;

  final int historyPoints;
  final int activityPoints;
  final int priceCoveragePoints;
  final int dataQualityPoints;
  final int opportunityPoints;

  final int totalTrips;
  final int tripsThisMonth;
  final int storesVisited;
  final int productsCompared;
  final int priceDropCount;
  final double savingsPotential;

  const SmartCartScore({
    required this.score,
    required this.grade,
    required this.title,
    required this.summary,
    required this.historyPoints,
    required this.activityPoints,
    required this.priceCoveragePoints,
    required this.dataQualityPoints,
    required this.opportunityPoints,
    required this.totalTrips,
    required this.tripsThisMonth,
    required this.storesVisited,
    required this.productsCompared,
    required this.priceDropCount,
    required this.savingsPotential,
  });

  const SmartCartScore.empty()
    : score = 0,
      grade = '—',
      title = 'Getting Started',
      summary =
          'Upload receipts and track products to build your SmartCart Score.',
      historyPoints = 0,
      activityPoints = 0,
      priceCoveragePoints = 0,
      dataQualityPoints = 0,
      opportunityPoints = 0,
      totalTrips = 0,
      tripsThisMonth = 0,
      storesVisited = 0,
      productsCompared = 0,
      priceDropCount = 0,
      savingsPotential = 0;

  bool get hasData =>
      totalTrips > 0 ||
      productsCompared > 0 ||
      priceDropCount > 0 ||
      savingsPotential > 0;

  double get progress => score / 100;

  bool get isExcellent => score >= 85;

  bool get isStrong => score >= 70;
}

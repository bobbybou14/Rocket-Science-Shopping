import '../models/savings_summary.dart';
import '../models/shopping_trip.dart';
import '../models/smartcart_score.dart';
import 'dashboard_intelligence_service.dart';

class SmartCartScoreService {
  static SmartCartScore calculate({
    required List<ShoppingTrip> trips,
    required SavingsSummary savingsSummary,
    required DashboardIntelligence intelligence,
    DateTime? now,
  }) {
    final currentDate = now ?? DateTime.now();

    final tripsThisMonth = trips.where((trip) {
      return trip.purchaseDate.year == currentDate.year &&
          trip.purchaseDate.month == currentDate.month;
    }).toList();

    final storesVisited = trips
        .map(_storeKey)
        .where((store) => store.isNotEmpty)
        .toSet()
        .length;

    final verifiedTrips = trips.where(_isVerifiedTrip).length;

    final historyPoints = _historyPoints(trips.length);

    final activityPoints = _activityPoints(tripsThisMonth.length);

    final priceCoveragePoints = _priceCoveragePoints(
      savingsSummary.purchasesCompared,
    );

    final dataQualityPoints = _dataQualityPoints(
      totalTrips: trips.length,
      verifiedTrips: verifiedTrips,
    );

    final opportunityPoints = _opportunityPoints(
      priceDropCount: savingsSummary.priceDropCount,
      savingsPotential: savingsSummary.watchlistSavingsPotential,
      dashboardAlertCount: intelligence.priceAlerts.length,
    );

    final score = [
      historyPoints,
      activityPoints,
      priceCoveragePoints,
      dataQualityPoints,
      opportunityPoints,
    ].fold<int>(0, (total, points) => total + points).clamp(0, 100);

    return SmartCartScore(
      score: score,
      grade: _grade(score),
      title: _title(score),
      summary: _summary(
        score: score,
        totalTrips: trips.length,
        tripsThisMonth: tripsThisMonth.length,
        productsCompared: savingsSummary.purchasesCompared,
      ),
      historyPoints: historyPoints,
      activityPoints: activityPoints,
      priceCoveragePoints: priceCoveragePoints,
      dataQualityPoints: dataQualityPoints,
      opportunityPoints: opportunityPoints,
      totalTrips: trips.length,
      tripsThisMonth: tripsThisMonth.length,
      storesVisited: storesVisited,
      productsCompared: savingsSummary.purchasesCompared,
      priceDropCount: savingsSummary.priceDropCount,
      savingsPotential: savingsSummary.watchlistSavingsPotential,
    );
  }

  static int _historyPoints(int tripCount) {
    if (tripCount <= 0) return 0;

    return (tripCount * 3).clamp(0, 25);
  }

  static int _activityPoints(int monthlyTripCount) {
    if (monthlyTripCount <= 0) return 0;

    return (monthlyTripCount * 4).clamp(0, 15);
  }

  static int _priceCoveragePoints(int productsCompared) {
    if (productsCompared <= 0) return 0;

    return (productsCompared * 3).clamp(0, 20);
  }

  static int _dataQualityPoints({
    required int totalTrips,
    required int verifiedTrips,
  }) {
    if (totalTrips <= 0) return 0;

    final verifiedRatio = verifiedTrips / totalTrips;

    return (verifiedRatio * 20).round().clamp(0, 20);
  }

  static int _opportunityPoints({
    required int priceDropCount,
    required double savingsPotential,
    required int dashboardAlertCount,
  }) {
    final priceDropPoints = (priceDropCount * 4).clamp(0, 12);

    final alertPoints = (dashboardAlertCount * 2).clamp(0, 5);

    int savingsPoints = 0;

    if (savingsPotential >= 25) {
      savingsPoints = 8;
    } else if (savingsPotential >= 15) {
      savingsPoints = 6;
    } else if (savingsPotential >= 5) {
      savingsPoints = 4;
    } else if (savingsPotential > 0) {
      savingsPoints = 2;
    }

    return (priceDropPoints + alertPoints + savingsPoints).clamp(0, 20);
  }

  static bool _isVerifiedTrip(ShoppingTrip trip) {
    final status = trip.processingStatus.trim().toLowerCase();

    return status == 'verified' ||
        status == 'processed' ||
        status == 'complete' ||
        status == 'completed';
  }

  static String _storeKey(ShoppingTrip trip) {
    if (trip.storeId.trim().isNotEmpty) {
      return trip.storeId.trim().toLowerCase();
    }

    return trip.storeName.trim().toLowerCase();
  }

  static String _grade(int score) {
    if (score >= 95) return 'A+';
    if (score >= 90) return 'A';
    if (score >= 85) return 'A−';
    if (score >= 80) return 'B+';
    if (score >= 75) return 'B';
    if (score >= 70) return 'B−';
    if (score >= 65) return 'C+';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';

    return 'F';
  }

  static String _title(int score) {
    if (score >= 90) {
      return 'Outstanding Intelligence';
    }

    if (score >= 80) {
      return 'Excellent Progress';
    }

    if (score >= 70) {
      return 'Strong Shopping Picture';
    }

    if (score >= 55) {
      return 'Intelligence Is Growing';
    }

    if (score >= 30) {
      return 'Building Your Score';
    }

    return 'Getting Started';
  }

  static String _summary({
    required int score,
    required int totalTrips,
    required int tripsThisMonth,
    required int productsCompared,
  }) {
    if (totalTrips == 0) {
      return 'Upload your first receipt to begin building shopping intelligence.';
    }

    if (productsCompared == 0) {
      return 'Your shopping history is growing. Track more products to unlock price comparisons.';
    }

    if (tripsThisMonth == 0) {
      return 'Your history is ready. Add a receipt this month to keep your score active.';
    }

    if (score >= 80) {
      return 'SmartCart has strong shopping history and price intelligence to work with.';
    }

    if (score >= 55) {
      return 'Your shopping picture is becoming more complete with every receipt.';
    }

    return 'Keep adding receipts and tracking products to strengthen your score.';
  }
}

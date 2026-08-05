import '../models/budget_intelligence.dart';
import '../models/shopping_trip.dart';

class BudgetIntelligenceService {
  static const double defaultMonthlyBudget = 600;

  static BudgetIntelligence calculate({
    required List<ShoppingTrip> trips,
    double monthlyBudget = defaultMonthlyBudget,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    final monthTrips = trips.where((trip) {
      return trip.purchaseDate.year == now.year &&
          trip.purchaseDate.month == now.month;
    }).toList();

    final spentThisMonth = monthTrips.fold<double>(
      0,
      (total, trip) => total + trip.total,
    );

    final tripCount = monthTrips.length;

    final averageTripCost = tripCount == 0 ? 0.0 : spentThisMonth / tripCount;

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    final daysElapsed = now.day.clamp(1, daysInMonth);

    final daysRemaining = (daysInMonth - daysElapsed).clamp(0, daysInMonth);

    final dailySpendingRate = daysElapsed <= 0
        ? 0.0
        : spentThisMonth / daysElapsed;

    final projectedMonthEndSpending = dailySpendingRate * daysInMonth;

    final remainingBudget = monthlyBudget - spentThisMonth;

    final budgetUsedPercentage = monthlyBudget <= 0
        ? 0.0
        : (spentThisMonth / monthlyBudget) * 100;

    final projectedDifference = projectedMonthEndSpending - monthlyBudget;

    final expectedUsagePercentage = daysElapsed / daysInMonth;

    final actualUsagePercentage = monthlyBudget <= 0
        ? 0.0
        : spentThisMonth / monthlyBudget;

    final status = _determineStatus(
      monthlyBudget: monthlyBudget,
      spentThisMonth: spentThisMonth,
      projectedMonthEndSpending: projectedMonthEndSpending,
      actualUsagePercentage: actualUsagePercentage,
      expectedUsagePercentage: expectedUsagePercentage,
    );

    return BudgetIntelligence(
      monthlyBudget: monthlyBudget,
      spentThisMonth: spentThisMonth,
      remainingBudget: remainingBudget,
      budgetUsedPercentage: budgetUsedPercentage,
      projectedMonthEndSpending: projectedMonthEndSpending,
      projectedDifference: projectedDifference,
      averageTripCost: averageTripCost,
      dailySpendingRate: dailySpendingRate,
      tripCount: tripCount,
      daysElapsed: daysElapsed,
      daysRemaining: daysRemaining,
      status: status,
    );
  }

  static BudgetStatus _determineStatus({
    required double monthlyBudget,
    required double spentThisMonth,
    required double projectedMonthEndSpending,
    required double actualUsagePercentage,
    required double expectedUsagePercentage,
  }) {
    if (monthlyBudget <= 0) {
      return BudgetStatus.onTrack;
    }

    if (spentThisMonth > monthlyBudget ||
        projectedMonthEndSpending > monthlyBudget * 1.05) {
      return BudgetStatus.overBudget;
    }

    if (projectedMonthEndSpending > monthlyBudget ||
        actualUsagePercentage > expectedUsagePercentage + 0.08) {
      return BudgetStatus.watch;
    }

    return BudgetStatus.onTrack;
  }
}

enum BudgetStatus { onTrack, watch, overBudget }

class BudgetIntelligence {
  final double monthlyBudget;
  final double spentThisMonth;
  final double remainingBudget;
  final double budgetUsedPercentage;
  final double projectedMonthEndSpending;
  final double projectedDifference;
  final double averageTripCost;
  final double dailySpendingRate;
  final int tripCount;
  final int daysElapsed;
  final int daysRemaining;
  final BudgetStatus status;

  const BudgetIntelligence({
    required this.monthlyBudget,
    required this.spentThisMonth,
    required this.remainingBudget,
    required this.budgetUsedPercentage,
    required this.projectedMonthEndSpending,
    required this.projectedDifference,
    required this.averageTripCost,
    required this.dailySpendingRate,
    required this.tripCount,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.status,
  });

  const BudgetIntelligence.empty()
    : monthlyBudget = 0,
      spentThisMonth = 0,
      remainingBudget = 0,
      budgetUsedPercentage = 0,
      projectedMonthEndSpending = 0,
      projectedDifference = 0,
      averageTripCost = 0,
      dailySpendingRate = 0,
      tripCount = 0,
      daysElapsed = 0,
      daysRemaining = 0,
      status = BudgetStatus.onTrack;

  bool get hasBudget => monthlyBudget > 0;

  bool get hasSpendingData => tripCount > 0;

  bool get isOnTrack => status == BudgetStatus.onTrack;

  bool get needsAttention => status == BudgetStatus.watch;

  bool get isOverBudget => status == BudgetStatus.overBudget;

  double get progressValue {
    if (monthlyBudget <= 0) {
      return 0;
    }

    return (spentThisMonth / monthlyBudget).clamp(0.0, 1.0);
  }

  double get projectedOverage {
    if (projectedDifference <= 0) {
      return 0;
    }

    return projectedDifference;
  }

  double get projectedSavings {
    if (projectedDifference >= 0) {
      return 0;
    }

    return projectedDifference.abs();
  }
}

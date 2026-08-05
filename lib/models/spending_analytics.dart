class MonthlySpendingPoint {
  final int year;
  final int month;
  final double totalSpent;
  final int tripCount;
  final double largestTrip;
  final double smallestTrip;

  const MonthlySpendingPoint({
    required this.year,
    required this.month,
    required this.totalSpent,
    required this.tripCount,
    required this.largestTrip,
    required this.smallestTrip,
  });

  double get averageTripCost {
    if (tripCount == 0) {
      return 0;
    }

    return totalSpent / tripCount;
  }

  String get monthLabel {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (month < 1 || month > 12) {
      return '';
    }

    return monthNames[month - 1];
  }

  String get fullMonthLabel {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (month < 1 || month > 12) {
      return '$year';
    }

    return '${monthNames[month - 1]} $year';
  }
}

class StoreSpendingPoint {
  final String storeName;
  final double totalSpent;
  final int tripCount;

  const StoreSpendingPoint({
    required this.storeName,
    required this.totalSpent,
    required this.tripCount,
  });
}

class SpendingAnalytics {
  final List<MonthlySpendingPoint> monthlySpending;
  final List<StoreSpendingPoint> topStores;
  final double currentMonthSpending;
  final double previousMonthSpending;
  final double monthlyChangeAmount;
  final double monthlyChangePercentage;
  final double averageTripCost;
  final double largestTrip;
  final double smallestTrip;
  final double averageDaysBetweenTrips;
  final String mostCommonShoppingDay;
  final int totalTrips;

  const SpendingAnalytics({
    required this.monthlySpending,
    required this.topStores,
    required this.currentMonthSpending,
    required this.previousMonthSpending,
    required this.monthlyChangeAmount,
    required this.monthlyChangePercentage,
    required this.averageTripCost,
    required this.largestTrip,
    required this.smallestTrip,
    required this.averageDaysBetweenTrips,
    required this.mostCommonShoppingDay,
    required this.totalTrips,
  });

  const SpendingAnalytics.empty()
    : monthlySpending = const [],
      topStores = const [],
      currentMonthSpending = 0,
      previousMonthSpending = 0,
      monthlyChangeAmount = 0,
      monthlyChangePercentage = 0,
      averageTripCost = 0,
      largestTrip = 0,
      smallestTrip = 0,
      averageDaysBetweenTrips = 0,
      mostCommonShoppingDay = 'Not enough data',
      totalTrips = 0;

  bool get hasData => totalTrips > 0;

  bool get hasPreviousMonthData => previousMonthSpending > 0;

  bool get spendingIncreased => monthlyChangeAmount > 0;

  bool get spendingDecreased => monthlyChangeAmount < 0;
}

import '../models/shopping_trip.dart';
import '../models/spending_analytics.dart';

class SpendingAnalyticsService {
  static SpendingAnalytics calculate({
    required List<ShoppingTrip> trips,
    DateTime? referenceDate,
  }) {
    final validTrips = trips.where((trip) => trip.total > 0).toList()
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    if (validTrips.isEmpty) {
      return const SpendingAnalytics.empty();
    }

    final now = referenceDate ?? DateTime.now();

    final monthlySpending = _buildMonthlySpending(
      trips: validTrips,
      referenceDate: now,
    );

    final currentMonthSpending = _totalForMonth(
      validTrips,
      now.year,
      now.month,
    );

    final previousMonthDate = DateTime(now.year, now.month - 1);

    final previousMonthSpending = _totalForMonth(
      validTrips,
      previousMonthDate.year,
      previousMonthDate.month,
    );

    final monthlyChangeAmount = currentMonthSpending - previousMonthSpending;

    final monthlyChangePercentage = previousMonthSpending <= 0
        ? 0.0
        : (monthlyChangeAmount / previousMonthSpending) * 100;

    final totalSpent = validTrips.fold<double>(
      0,
      (total, trip) => total + trip.total,
    );

    final totals = validTrips.map((trip) => trip.total).toList();

    return SpendingAnalytics(
      monthlySpending: monthlySpending,
      topStores: _buildTopStores(validTrips),
      currentMonthSpending: currentMonthSpending,
      previousMonthSpending: previousMonthSpending,
      monthlyChangeAmount: monthlyChangeAmount,
      monthlyChangePercentage: monthlyChangePercentage,
      averageTripCost: totalSpent / validTrips.length,
      largestTrip: totals.reduce((a, b) => a > b ? a : b),
      smallestTrip: totals.reduce((a, b) => a < b ? a : b),
      averageDaysBetweenTrips: _averageDaysBetweenTrips(validTrips),
      mostCommonShoppingDay: _mostCommonShoppingDay(validTrips),
      totalTrips: validTrips.length,
    );
  }

  static List<MonthlySpendingPoint> _buildMonthlySpending({
    required List<ShoppingTrip> trips,
    required DateTime referenceDate,
  }) {
    final results = <MonthlySpendingPoint>[];

    for (var monthsAgo = 5; monthsAgo >= 0; monthsAgo--) {
      final date = DateTime(
        referenceDate.year,
        referenceDate.month - monthsAgo,
      );

      final matchingTrips = trips.where((trip) {
        return trip.purchaseDate.year == date.year &&
            trip.purchaseDate.month == date.month;
      }).toList();

      final total = matchingTrips.fold<double>(
        0,
        (sum, trip) => sum + trip.total,
      );

      final tripTotals = matchingTrips
          .map((trip) => trip.total)
          .where((total) => total > 0)
          .toList();

      final largestTrip = tripTotals.isEmpty
          ? 0.0
          : tripTotals.reduce((a, b) => a > b ? a : b);

      final smallestTrip = tripTotals.isEmpty
          ? 0.0
          : tripTotals.reduce((a, b) => a < b ? a : b);

      results.add(
        MonthlySpendingPoint(
          year: date.year,
          month: date.month,
          totalSpent: total,
          tripCount: matchingTrips.length,
          largestTrip: largestTrip,
          smallestTrip: smallestTrip,
        ),
      );
    }

    return results;
  }

  static List<StoreSpendingPoint> _buildTopStores(List<ShoppingTrip> trips) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    final displayNames = <String, String>{};

    for (final trip in trips) {
      final cleanedName = trip.storeName.trim();
      final displayName = cleanedName.isEmpty ? 'Unknown Store' : cleanedName;
      final key = displayName.toLowerCase();

      totals[key] = (totals[key] ?? 0) + trip.total;
      counts[key] = (counts[key] ?? 0) + 1;
      displayNames[key] = displayName;
    }

    final stores = totals.entries.map((entry) {
      return StoreSpendingPoint(
        storeName: displayNames[entry.key] ?? 'Unknown Store',
        totalSpent: entry.value,
        tripCount: counts[entry.key] ?? 0,
      );
    }).toList();

    stores.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    return stores.take(4).toList();
  }

  static double _totalForMonth(List<ShoppingTrip> trips, int year, int month) {
    return trips
        .where((trip) {
          return trip.purchaseDate.year == year &&
              trip.purchaseDate.month == month;
        })
        .fold<double>(0, (total, trip) => total + trip.total);
  }

  static double _averageDaysBetweenTrips(List<ShoppingTrip> sortedTrips) {
    if (sortedTrips.length < 2) {
      return 0;
    }

    double totalDays = 0;
    var intervalCount = 0;

    for (var index = 1; index < sortedTrips.length; index++) {
      final previousDate = _dateOnly(sortedTrips[index - 1].purchaseDate);

      final currentDate = _dateOnly(sortedTrips[index].purchaseDate);

      final difference = currentDate.difference(previousDate).inDays;

      if (difference >= 0) {
        totalDays += difference;
        intervalCount++;
      }
    }

    if (intervalCount == 0) {
      return 0;
    }

    return totalDays / intervalCount;
  }

  static String _mostCommonShoppingDay(List<ShoppingTrip> trips) {
    final weekdayCounts = <int, int>{};

    for (final trip in trips) {
      final weekday = trip.purchaseDate.weekday;

      weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
    }

    if (weekdayCounts.isEmpty) {
      return 'Not enough data';
    }

    var mostCommonWeekday = DateTime.monday;
    var highestCount = 0;

    for (final entry in weekdayCounts.entries) {
      if (entry.value > highestCount) {
        mostCommonWeekday = entry.key;
        highestCount = entry.value;
      }
    }

    return _weekdayName(mostCommonWeekday);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _weekdayName(int weekday) {
    const weekdayNames = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };

    return weekdayNames[weekday] ?? 'Not available';
  }
}

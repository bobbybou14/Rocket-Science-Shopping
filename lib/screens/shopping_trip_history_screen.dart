import 'package:flutter/material.dart';

import '../models/shopping_trip.dart';
import '../service/shopping_trip_service.dart';
import 'shopping_trip_details_screen.dart';

class ShoppingTripHistoryScreen extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;

  const ShoppingTripHistoryScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
  });

  @override
  State<ShoppingTripHistoryScreen> createState() =>
      _ShoppingTripHistoryScreenState();
}

class _ShoppingTripHistoryScreenState extends State<ShoppingTripHistoryScreen> {
  List<ShoppingTrip> trips = [];
  String searchQuery = '';

  int? selectedYear;
  int? selectedMonth;

  bool isLoading = true;
  String? errorMessage;

  List<ShoppingTrip> get filteredTrips {
    Iterable<ShoppingTrip> results = trips;

    if (selectedYear != null && selectedMonth != null) {
      results = results.where((trip) {
        return trip.purchaseDate.year == selectedYear &&
            trip.purchaseDate.month == selectedMonth;
      });
    }

    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return results.toList();
    }

    return results.where((trip) {
      final store = trip.storeName.toLowerCase();
      final city = trip.city.toLowerCase();
      final province = trip.province.toLowerCase();
      final status = trip.processingStatus.toLowerCase();
      final date = formatDate(trip.purchaseDate).toLowerCase();

      return store.contains(query) ||
          city.contains(query) ||
          province.contains(query) ||
          status.contains(query) ||
          date.contains(query);
    }).toList();
  }

  double get filteredTotal {
    return filteredTrips.fold<double>(0, (total, trip) => total + trip.total);
  }

  @override
  void initState() {
    super.initState();

    selectedYear = widget.initialYear;
    selectedMonth = widget.initialMonth;

    loadTrips();
  }

  Future<void> loadTrips() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await ShoppingTripService.getShoppingTrips();

      if (!mounted) return;

      setState(() {
        trips = results;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load shopping trips: $error';
      });
    }
  }

  Future<void> openTripDetails(ShoppingTrip trip) async {
    final wasDeleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingTripDetailsScreen(shoppingTripId: trip.id),
      ),
    );

    if (wasDeleted == true) {
      await loadTrips();
    }
  }

  String formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String selectedMonthLabel() {
    final year = selectedYear;
    final month = selectedMonth;

    if (year == null || month == null || month < 1 || month > 12) {
      return '';
    }

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

    return '${monthNames[month - 1]} $year';
  }

  void clearMonthFilter() {
    setState(() {
      selectedYear = null;
      selectedMonth = null;
    });
  }

  String displayStoreName(ShoppingTrip trip) {
    if (trip.storeName.trim().isNotEmpty) {
      return trip.storeName;
    }

    return 'Unknown Store';
  }

  Widget tripCard(ShoppingTrip trip) {
    final location = [
      trip.city,
      trip.province,
    ].where((value) => value.trim().isNotEmpty).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(child: Icon(Icons.shopping_bag)),
        title: Text(
          displayStoreName(trip),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${formatDate(trip.purchaseDate)}'
          '${location.isEmpty ? "" : "\n$location"}'
          '\nStatus: ${trip.processingStatus}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${trip.total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => openTripDetails(trip),
      ),
    );
  }

  Widget searchField() {
    return TextField(
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      decoration: const InputDecoration(
        hintText: 'Search by store, location, date, or status',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget monthFilterCard() {
    if (selectedYear == null || selectedMonth == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.calendar_month_outlined)),
        title: const Text(
          'Month Filter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(selectedMonthLabel()),
        trailing: TextButton.icon(
          onPressed: clearMonthFilter,
          icon: const Icon(Icons.close),
          label: const Text('Clear'),
        ),
      ),
    );
  }

  Widget summaryHeader() {
    final visibleTrips = filteredTrips;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trips', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${visibleTrips.length}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Spent', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${filteredTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget bodyContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60),
              const SizedBox(height: 16),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loadTrips,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (trips.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 80),
              SizedBox(height: 16),
              Text(
                'No shopping trips saved yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Processed receipts will appear here after they are saved.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final visibleTrips = filteredTrips;

    return RefreshIndicator(
      onRefresh: loadTrips,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          monthFilterCard(),
          searchField(),
          const SizedBox(height: 14),
          summaryHeader(),
          if (visibleTrips.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 64),
                  SizedBox(height: 14),
                  Text(
                    'No matching shopping trips.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            ...visibleTrips.map(tripCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedYear != null && selectedMonth != null
              ? selectedMonthLabel()
              : 'Shopping Trip History',
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadTrips,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: bodyContent(),
    );
  }
}

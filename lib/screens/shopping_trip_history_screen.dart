import 'package:flutter/material.dart';

import '../models/shopping_trip.dart';
import '../service/shopping_trip_service.dart';
import 'shopping_trip_details_screen.dart';

class ShoppingTripHistoryScreen extends StatefulWidget {
  const ShoppingTripHistoryScreen({super.key});

  @override
  State<ShoppingTripHistoryScreen> createState() =>
      _ShoppingTripHistoryScreenState();
}

class _ShoppingTripHistoryScreenState extends State<ShoppingTripHistoryScreen> {
  List<ShoppingTrip> trips = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
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

    return RefreshIndicator(
      onRefresh: loadTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          return tripCard(trips[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Trip History'),
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

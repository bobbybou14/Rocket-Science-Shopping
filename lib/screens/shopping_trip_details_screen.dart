import 'package:flutter/material.dart';

import '../models/shopping_trip.dart';
import '../service/shopping_trip_service.dart';

class ShoppingTripDetailsScreen extends StatefulWidget {
  final String shoppingTripId;

  const ShoppingTripDetailsScreen({super.key, required this.shoppingTripId});

  @override
  State<ShoppingTripDetailsScreen> createState() =>
      _ShoppingTripDetailsScreenState();
}

class _ShoppingTripDetailsScreenState extends State<ShoppingTripDetailsScreen> {
  ShoppingTrip? trip;
  bool isLoading = true;
  bool isDeleting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadTrip();
  }

  Future<void> loadTrip() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ShoppingTripService.getShoppingTrip(
        widget.shoppingTripId,
      );

      if (!mounted) return;

      setState(() {
        trip = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load shopping trip: $error';
      });
    }
  }

  Future<void> deleteTrip() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Shopping Trip'),
          content: const Text(
            'This will permanently delete the shopping trip and all of its items.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      isDeleting = true;
    });

    try {
      await ShoppingTripService.deleteShoppingTrip(widget.shoppingTripId);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete shopping trip: $error')),
      );
    }
  }

  String formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Color confidenceColour(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 55) return Colors.orange;

    return Colors.red;
  }

  Widget summaryCard(ShoppingTrip trip) {
    final location = [
      trip.city,
      trip.province,
    ].where((value) => value.trim().isNotEmpty).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              trip.storeName.isEmpty ? 'Unknown Store' : trip.storeName,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(location, style: const TextStyle(fontSize: 17)),
            ],
            const SizedBox(height: 14),
            Text('Purchase date: ${formatDate(trip.purchaseDate)}'),
            Text('Status: ${trip.processingStatus}'),
            Text('Source: ${trip.source}'),
            const Divider(height: 28),
            Text('Subtotal: \$${trip.subtotal.toStringAsFixed(2)}'),
            Text('Tax: \$${trip.tax.toStringAsFixed(2)}'),
            Text(
              'Total: \$${trip.total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget itemCard(ShoppingTripItem item) {
    final product = item.product;

    final matchedName = product == null
        ? 'No matched product'
        : [
            product.brand,
            product.name,
            product.size,
          ].where((value) => value.trim().isNotEmpty).join(' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.requiresReview ? Icons.warning_amber : Icons.check_circle,
              color: confidenceColour(item.confidenceScore),
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.rawReceiptName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(matchedName),
                  const SizedBox(height: 4),
                  Text('Quantity: ${item.quantity.toStringAsFixed(3)}'),
                  Text('Unit price: \$${item.unitPrice.toStringAsFixed(2)}'),
                  Text('Line total: \$${item.lineTotal.toStringAsFixed(2)}'),
                  Text(
                    'Confidence: ${item.confidenceScore.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: confidenceColour(item.confidenceScore),
                    ),
                  ),
                  Text(item.requiresReview ? 'Review required' : 'Verified'),
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
                onPressed: loadTrip,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final currentTrip = trip;

    if (currentTrip == null) {
      return const Center(child: Text('Shopping trip not found.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        summaryCard(currentTrip),
        const SizedBox(height: 16),
        Text(
          'Items (${currentTrip.items.length})',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (currentTrip.items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No shopping trip items were found.'),
            ),
          )
        else
          ...currentTrip.items.map(itemCard),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isDeleting ? null : deleteTrip,
          icon: isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
          label: Text(isDeleting ? 'Deleting...' : 'Delete Shopping Trip'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Trip Details'),
        actions: [
          IconButton(
            onPressed: isLoading || isDeleting ? null : loadTrip,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: bodyContent(),
    );
  }
}

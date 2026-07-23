import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/product.dart';
import '../service/price_history_service.dart';
import '../widgets/price/price_history_chart.dart';
import '../widgets/price/price_history_list.dart';
import '../widgets/price/price_statistics_card.dart';

class PriceHistoryScreen extends StatefulWidget {
  final Product product;

  const PriceHistoryScreen({super.key, required this.product});

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  PriceHistorySummary? summary;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadPriceHistory();
  }

  Future<void> loadPriceHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await PriceHistoryService.getPriceHistory(
        widget.product.barcode,
      );

      if (!mounted) return;

      setState(() {
        summary = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load price history: $error';
      });
    }
  }

  String get productDisplayName {
    final parts = [
      widget.product.brand,
      widget.product.name,
      widget.product.size,
    ].where((value) => value.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'Unknown Product';
    }

    return parts.join(' ');
  }

  Widget productHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: widget.product.imageUrl.trim().isEmpty
                  ? const Icon(
                      Icons.inventory_2,
                      size: 34,
                      color: AppColors.primary,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        widget.product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return const Icon(
                            Icons.inventory_2,
                            size: 34,
                            color: AppColors.primary,
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productDisplayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Barcode: ${widget.product.barcode}'),
                  if (widget.product.category.trim().isNotEmpty)
                    Text(
                      'Category: '
                      '${widget.product.category}',
                    ),
                  const SizedBox(height: 6),
                  Text(
                    widget.product.taxable ? 'Ontario HST applies' : 'No HST',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget loadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Price History Could Not Be Loaded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: loadPriceHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget priceHistoryContent(PriceHistorySummary data) {
    return RefreshIndicator(
      onRefresh: loadPriceHistory,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          productHeader(),
          const SizedBox(height: 16),
          PriceStatisticsCard(summary: data),
          const SizedBox(height: 16),
          PriceHistoryChart(entries: data.entries),
          const SizedBox(height: 22),
          PriceHistoryList(entries: data.entries),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget bodyContent() {
    if (isLoading) {
      return loadingState();
    }

    if (errorMessage != null) {
      return errorState();
    }

    final data = summary;

    if (data == null) {
      return const Center(
        child: Text('No price history information was found.'),
      );
    }

    return priceHistoryContent(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Intelligence'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadPriceHistory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Price History',
          ),
        ],
      ),
      body: bodyContent(),
    );
  }
}

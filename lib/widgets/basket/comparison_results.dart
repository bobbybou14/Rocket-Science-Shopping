import 'package:flutter/material.dart';

import '../../service/basket_comparison_service.dart';
import '../store_comparison_card.dart';

class ComparisonResults extends StatelessWidget {
  final BasketComparisonResult result;

  const ComparisonResults({super.key, required this.result});

  Widget cheapestBasketSummary() {
    final cheapest = result.cheapestCompleteStore;

    if (cheapest == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.warning_amber, size: 46, color: Colors.orange),
              SizedBox(height: 12),
              Text(
                'No Complete Basket Available',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'No store currently has recorded prices for every item in this basket. '
                'Partial totals are shown below but are not eligible for cheapest-basket ranking.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, size: 32, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cheapest Complete Basket',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              cheapest.storeName,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${cheapest.total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              result.potentialSavings > 0
                  ? 'Potential savings compared with the highest complete basket: '
                        '\$${result.potentialSavings.toStringAsFixed(2)}'
                  : 'No savings difference is available between complete baskets.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cheapest = result.cheapestCompleteStore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        const Text(
          'Comparison Results',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        cheapestBasketSummary(),
        const SizedBox(height: 14),
        ...result.stores.map(
          (store) => StoreComparisonCard(
            store: store,
            isCheapest: cheapest != null && store.storeId == cheapest.storeId,
            potentialSavings: result.potentialSavings,
          ),
        ),
      ],
    );
  }
}

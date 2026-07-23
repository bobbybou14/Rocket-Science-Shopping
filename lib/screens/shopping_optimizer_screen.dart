import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../service/shopping_optimizer_service.dart';

class ShoppingOptimizerScreen extends StatefulWidget {
  final List<CartItem> cart;

  const ShoppingOptimizerScreen({super.key, required this.cart});

  @override
  State<ShoppingOptimizerScreen> createState() =>
      _ShoppingOptimizerScreenState();
}

class _ShoppingOptimizerScreenState extends State<ShoppingOptimizerScreen> {
  List<StoreRecommendation> recommendations = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRecommendations();
  }

  Future<void> loadRecommendations() async {
    final results = await ShoppingOptimizerService.optimize(widget.cart);

    if (!mounted) return;

    setState(() {
      recommendations = results;
      loading = false;
    });
  }

  double get savings {
    if (recommendations.length < 2) return 0;
    return recommendations.last.total - recommendations.first.total;
  }

  Widget recommendationCard(StoreRecommendation rec, int index) {
    final isBest = index == 0;

    return Card(
      child: ListTile(
        leading: Icon(
          isBest ? Icons.emoji_events : Icons.store,
          color: isBest ? Colors.orange : Colors.red,
        ),
        title: Text(
          rec.store.isEmpty ? 'Unknown Store' : rec.store,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Items available: ${rec.itemsFound} / ${rec.totalItems}',
        ),
        trailing: Text(
          '\$${rec.total.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isBest ? Colors.green : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final best = recommendations.isEmpty ? null : recommendations.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Optimizer')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : recommendations.isEmpty
          ? const Center(
              child: Text(
                'No price data available for this cart yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadRecommendations,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    '🏆 Best Shopping Trip',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (best != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              best.store.isEmpty ? 'Unknown Store' : best.store,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '\$${best.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Items available: ${best.itemsFound} / ${best.totalItems}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (savings > 0) ...[
                              const Divider(height: 30),
                              Text(
                                'Estimated savings: \$${savings.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Other Store Options',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...recommendations.asMap().entries.map(
                    (entry) => recommendationCard(entry.value, entry.key),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

import '../models/cart_item.dart';
import '../models/price.dart';
import 'price_service.dart';

class DashboardInsights {
  final double potentialSavings;
  final String bestStore;
  final int productsWithKnownPrices;
  final int productsWithoutKnownPrices;

  const DashboardInsights({
    required this.potentialSavings,
    required this.bestStore,
    required this.productsWithKnownPrices,
    required this.productsWithoutKnownPrices,
  });

  const DashboardInsights.empty()
    : potentialSavings = 0,
      bestStore = '--',
      productsWithKnownPrices = 0,
      productsWithoutKnownPrices = 0;

  bool get hasPriceData => productsWithKnownPrices > 0;

  int get productsAnalyzed =>
      productsWithKnownPrices + productsWithoutKnownPrices;

  double get coveragePercentage {
    if (productsAnalyzed == 0) {
      return 0;
    }

    return productsWithKnownPrices / productsAnalyzed * 100;
  }
}

class DashboardService {
  /// Total quantity of all items in the cart.
  static int cartItemCount(List<CartItem> cart) {
    return cart.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  /// Number of distinct product lines in the cart.
  static int cartProductCount(List<CartItem> cart) {
    return cart.length;
  }

  /// Total cost using the prices currently stored in the cart.
  static double cartTotal(List<CartItem> cart) {
    return cart.fold<double>(0, (sum, item) => sum + item.total);
  }

  /// Loads all dashboard pricing intelligence in one pass.
  ///
  /// Each product's lowest known price is requested only once.
  static Future<DashboardInsights> loadInsights(List<CartItem> cart) async {
    if (cart.isEmpty) {
      return const DashboardInsights.empty();
    }

    final lowestPrices = await Future.wait<Price?>(
      cart.map((item) => PriceService.getLowestPrice(item.barcode)),
    );

    double potentialSavings = 0;
    int productsWithKnownPrices = 0;
    int productsWithoutKnownPrices = 0;

    final storeSavings = <String, double>{};
    final storeWins = <String, int>{};

    for (var index = 0; index < cart.length; index++) {
      final item = cart[index];
      final cheapest = lowestPrices[index];

      if (cheapest == null) {
        productsWithoutKnownPrices++;
        continue;
      }

      productsWithKnownPrices++;

      final storeName = cheapest.store.trim();

      if (storeName.isNotEmpty) {
        storeWins.update(storeName, (count) => count + 1, ifAbsent: () => 1);
      }

      if (cheapest.price >= item.price) {
        continue;
      }

      final itemSavings = (item.price - cheapest.price) * item.quantity;

      potentialSavings += itemSavings;

      if (storeName.isNotEmpty) {
        storeSavings.update(
          storeName,
          (value) => value + itemSavings,
          ifAbsent: () => itemSavings,
        );
      }
    }

    return DashboardInsights(
      potentialSavings: potentialSavings,
      bestStore: _selectBestStore(
        storeWins: storeWins,
        storeSavings: storeSavings,
      ),
      productsWithKnownPrices: productsWithKnownPrices,
      productsWithoutKnownPrices: productsWithoutKnownPrices,
    );
  }

  /// Maintained for compatibility with existing callers.
  static Future<double> potentialSavings(List<CartItem> cart) async {
    final insights = await loadInsights(cart);
    return insights.potentialSavings;
  }

  /// Maintained for compatibility with existing callers.
  static Future<String> bestStore(List<CartItem> cart) async {
    final insights = await loadInsights(cart);
    return insights.bestStore;
  }

  static String _selectBestStore({
    required Map<String, int> storeWins,
    required Map<String, double> storeSavings,
  }) {
    if (storeWins.isEmpty) {
      return '--';
    }

    final stores = storeWins.keys.toList()
      ..sort((a, b) {
        final winComparison = storeWins[b]!.compareTo(storeWins[a]!);

        if (winComparison != 0) {
          return winComparison;
        }

        final savingsComparison = (storeSavings[b] ?? 0).compareTo(
          storeSavings[a] ?? 0,
        );

        if (savingsComparison != 0) {
          return savingsComparison;
        }

        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return stores.first;
  }
}

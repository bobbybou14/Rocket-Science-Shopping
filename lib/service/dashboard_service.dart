import '../models/cart_item.dart';
import '../models/price.dart';
import 'price_service.dart';

class DashboardService {
  /// Total number of items in the cart.
  static int cartItemCount(List<CartItem> cart) {
    return cart.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Total cost using the prices currently in the cart.
  static double cartTotal(List<CartItem> cart) {
    return cart.fold(0, (sum, item) => sum + item.total);
  }

  /// Calculates the maximum savings if every item was purchased
  /// at its cheapest known price.
  static Future<double> potentialSavings(List<CartItem> cart) async {
    double savings = 0;

    for (final item in cart) {
      final Price? cheapest = await PriceService.getLowestPrice(item.barcode);

      if (cheapest != null && cheapest.price < item.price) {
        savings += (item.price - cheapest.price) * item.quantity;
      }
    }

    return savings;
  }

  /// Returns the store with the most "best prices".
  static Future<String> bestStore(List<CartItem> cart) async {
    final Map<String, int> winners = {};

    for (final item in cart) {
      final Price? cheapest = await PriceService.getLowestPrice(item.barcode);

      if (cheapest == null) continue;

      winners.update(cheapest.store, (count) => count + 1, ifAbsent: () => 1);
    }

    if (winners.isEmpty) {
      return '--';
    }

    final sorted = winners.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }
}

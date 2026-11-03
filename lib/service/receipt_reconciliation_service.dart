/// Checks draft amounts without changing any receipt or item amount.
/// Comparisons use integer cents, so a one-cent discrepancy remains visible.
class ReceiptReconciliationService {
  const ReceiptReconciliationService._();

  static String money(double amount) => '\$${amount.toStringAsFixed(2)}';

  static int cents(double amount) => (amount * 100).round();

  static String? issue({
    required double receiptSubtotal,
    required double receiptTotal,
    required double tax,
    required double itemSubtotal,
    required int unresolvedPrices,
  }) {
    if (![
      receiptSubtotal,
      receiptTotal,
      tax,
      itemSubtotal,
    ].every((value) => value.isFinite)) {
      return 'An amount is invalid. Check receipt details.';
    }
    if (unresolvedPrices > 0) {
      return '$unresolvedPrices item price(s) could not be read. '
          'Edit those prices before confirming.';
    }
    if (receiptSubtotal > 0 && cents(itemSubtotal) != cents(receiptSubtotal)) {
      final difference = (receiptSubtotal - itemSubtotal).abs();
      final direction = itemSubtotal < receiptSubtotal ? 'short' : 'over';
      return 'Item amounts are ${money(difference)} $direction of the receipt '
          'subtotal. Check missing items and prices.';
    }
    if (receiptTotal > 0 && cents(itemSubtotal + tax) != cents(receiptTotal)) {
      return 'Item amounts plus tax do not match the receipt total '
          '${money(receiptTotal)}.';
    }
    if (receiptSubtotal <= 0 && receiptTotal <= 0) {
      return 'The receipt totals could not be read. Verify the receipt totals '
          'before confirming.';
    }
    return null;
  }
}

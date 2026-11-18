import '../models/shopping_trip.dart';

/// Suggests trips for explicit user selection. Never merges by itself.
class ReceiptTripMatchService {
  const ReceiptTripMatchService._();

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isCandidate(ShoppingTrip receipt, ShoppingTrip saved) {
    if (receipt.id.isNotEmpty && receipt.id == saved.id) return false;
    final receiptDay = startOfDay(receipt.purchaseDate);
    final legacyLive =
        saved.source == 'live_shopping' && saved.storeId.trim().isEmpty;
    final savedDay = startOfDay(
      legacyLive ? saved.purchaseDate : saved.purchaseDate.toLocal(),
    );
    if (receiptDay != savedDay) return false;
    if (receipt.storeId.trim().isNotEmpty && saved.storeId.trim().isNotEmpty) {
      return receipt.storeId.trim() == saved.storeId.trim();
    }
    final name = _normalize(receipt.storeName);
    if (name.isEmpty || name != _normalize(saved.storeName)) return false;
    // Earlier live trips omitted branch IDs and cities. Offer these for
    // manual selection, with a warning in the picker about the missing branch.
    return receipt.city.trim().isEmpty ||
        saved.city.trim().isEmpty ||
        _normalize(receipt.city) == _normalize(saved.city);
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

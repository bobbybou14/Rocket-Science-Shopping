import '../models/live_cart_item.dart';
import '../models/product.dart';

class LiveCartService {
  static final List<LiveCartItem> _items = [];

  static List<LiveCartItem> get items =>
      List.unmodifiable(_items);

  static bool get isEmpty => _items.isEmpty;

  static bool get isNotEmpty => _items.isNotEmpty;

  static int get itemCount => _items.fold(
        0,
        (total, item) => total + item.quantity,
      );

  static int get uniqueItemCount => _items.length;

  static double get totalCost => _items.fold(
        0.0,
        (total, item) => total + item.totalPrice,
      );

  static void clear() {
    _items.clear();
  }

  static bool containsBarcode(String barcode) {
    return _items.any(
      (item) => item.barcode == barcode,
    );
  }

  static LiveCartItem? findByBarcode(String barcode) {
    try {
      return _items.firstWhere(
        (item) => item.barcode == barcode,
      );
    } catch (_) {
      return null;
    }
  }

  static void addProduct({
  required Product product,
  required double unitPrice,
  required String storeName,
}) {
  final index = _items.indexWhere(
    (item) => item.barcode == product.barcode,
  );

  if (index >= 0) {
    _items[index] = _items[index]
        .updatePrice(unitPrice)
        .updateStore(storeName)
        .increaseQuantity();

    return;
  }

  _items.add(
    LiveCartItem(
      product: product,
      unitPrice: unitPrice,
      quantity: 1,
      storeName: storeName,
      addedAt: DateTime.now(),
    ),
  );
}

  static void removeProduct(String barcode) {
    _items.removeWhere(
      (item) => item.barcode == barcode,
    );
  }

  static void increaseQuantity(String barcode) {
    final index = _items.indexWhere(
      (item) => item.barcode == barcode,
    );

    if (index == -1) return;

    _items[index] =
        _items[index].increaseQuantity();
  }

  static void decreaseQuantity(String barcode) {
    final index = _items.indexWhere(
      (item) => item.barcode == barcode,
    );

    if (index == -1) return;

    final item = _items[index];

    if (item.quantity <= 1) {
      _items.removeAt(index);
      return;
    }

    _items[index] = item.decreaseQuantity();
  }

  static void updateQuantity(
    String barcode,
    int quantity,
  ) {
    final index = _items.indexWhere(
      (item) => item.barcode == barcode,
    );

    if (index == -1) return;

    if (quantity <= 0) {
      _items.removeAt(index);
      return;
    }

    _items[index] =
        _items[index].updateQuantity(quantity);
  }

  static void updatePrice(
    String barcode,
    double newPrice,
  ) {
    final index = _items.indexWhere(
      (item) => item.barcode == barcode,
    );

    if (index == -1) return;

    _items[index] =
        _items[index].updatePrice(newPrice);
  }

  static void updateStore(
    String barcode,
    String storeName,
  ) {
    final index = _items.indexWhere(
      (item) => item.barcode == barcode,
    );

    if (index == -1) return;

    _items[index] =
        _items[index].updateStore(storeName);
  }
}
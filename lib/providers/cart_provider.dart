import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  int get uniqueItemCount => _items.length;

  int get itemCount => _items.fold(0, (total, item) => total + item.quantity);

  double get subtotal =>
      _items.fold(0.0, (total, item) => total + item.subtotal);

  double get tax => _items.fold(0.0, (total, item) => total + item.tax);

  double get total => subtotal + tax;

  void addItem(CartItem item) {
    final barcode = item.barcode.trim();

    final index = barcode.isEmpty
        ? -1
        : _items.indexWhere((existing) => existing.barcode.trim() == barcode);

    if (index >= 0) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }

    notifyListeners();
  }

  void increaseQuantity(CartItem item) {
    item.quantity++;
    notifyListeners();
  }

  void decreaseQuantity(CartItem item) {
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(item);
    }

    notifyListeners();
  }

  void setQuantity(CartItem item, int quantity) {
    if (quantity <= 0) {
      _items.remove(item);
    } else {
      item.quantity = quantity;
    }

    notifyListeners();
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void restoreItem(CartItem item) {
    final barcode = item.barcode.trim();

    final alreadyExists =
        barcode.isNotEmpty &&
        _items.any((existing) => existing.barcode.trim() == barcode);

    if (!alreadyExists) {
      _items.add(item);
      notifyListeners();
    }
  }

  void updatePrice(CartItem item, double newPrice) {
    item.price = newPrice;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  bool containsBarcode(String barcode) {
    return _items.any((item) => item.barcode == barcode);
  }

  CartItem? findByBarcode(String barcode) {
    try {
      return _items.firstWhere((item) => item.barcode == barcode);
    } catch (_) {
      return null;
    }
  }
}

import 'product.dart';

class LiveCartItem {
  final Product product;
  final double unitPrice;
  final int quantity;
  final String storeName;
  final DateTime addedAt;

  const LiveCartItem({
    required this.product,
    required this.unitPrice,
    required this.quantity,
    required this.storeName,
    required this.addedAt,
  });

  double get totalPrice => unitPrice * quantity;

  String get barcode => product.barcode;

  String get productName => product.name;

  bool get hasKnownPrice => unitPrice > 0;

  LiveCartItem copyWith({
    Product? product,
    double? unitPrice,
    int? quantity,
    String? storeName,
    DateTime? addedAt,
  }) {
    return LiveCartItem(
      product: product ?? this.product,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      storeName: storeName ?? this.storeName,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  LiveCartItem increaseQuantity() {
    return copyWith(
      quantity: quantity + 1,
    );
  }

  LiveCartItem decreaseQuantity() {
    return copyWith(
      quantity: quantity > 1 ? quantity - 1 : 1,
    );
  }

  LiveCartItem updateQuantity(int newQuantity) {
    return copyWith(
      quantity: newQuantity < 1 ? 1 : newQuantity,
    );
  }

  LiveCartItem updatePrice(double newPrice) {
    return copyWith(
      unitPrice: newPrice < 0 ? 0 : newPrice,
    );
  }

  LiveCartItem updateStore(String newStoreName) {
    return copyWith(
      storeName: newStoreName.trim(),
    );
  }
}
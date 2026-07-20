import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  double price;

  CartItem({
    required this.product,
    required this.price,
    this.quantity = 1,
  });

  String get barcode => product.barcode;
  String get name => product.name;
  String get brand => product.brand;
  String get category => product.category;
  String get size => product.size;
  String get imageUrl => product.imageUrl;
  bool get taxable => product.taxable;

  double get subtotal => price * quantity;

  double get tax => taxable ? subtotal * 0.13 : 0;

  double get total => subtotal + tax;
}
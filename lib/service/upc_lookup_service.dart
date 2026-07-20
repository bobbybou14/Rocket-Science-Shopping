import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/cart_item.dart';
import '../models/product.dart';

class UpcLookupService {
static Future<CartItem?> lookup(String barcode) async {
  try {
    final url = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);

    if (data['status'] != 1) {
      return null;
    }

    final productData = data['product'];

    final product = Product(
      barcode: barcode,
      name: productData['product_name'] ?? 'Unknown Product',
      brand: productData['brands'] ?? '',
      size: productData['quantity'] ?? '',
      imageUrl: productData['image_front_url'] ?? '',
      taxable: false,
    );

    return CartItem(
      product: product,
      price: 0.00,
    );
  } catch (_) {
    return null;
   }
  }
}
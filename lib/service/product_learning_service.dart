import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/product_suggestion.dart';
import 'product_alias_service.dart';
import 'product_service.dart';
import 'supabase_product_service.dart';

class ProductLearningResult {
  final Product? product;
  final bool productSaved;
  final bool aliasSaved;
  final String message;

  const ProductLearningResult({
    required this.product,
    required this.productSaved,
    required this.aliasSaved,
    required this.message,
  });

  bool get success => productSaved && product != null;

  bool get fullyLearned => success && aliasSaved;
}

class ProductLearningService {
  ProductLearningService._();

  static Future<ProductLearningResult> saveSuggestion({
    required ProductSuggestion suggestion,
    required String receiptItemName,
    String imageUrl = '',
  }) async {
    if (!suggestion.isReadyToSave) {
      return _failure('A product name and barcode are required.');
    }

    try {
      final product = suggestion.toProduct(imageUrl: imageUrl);

      return await saveProduct(
        product: product,
        receiptItemName: receiptItemName,
      );
    } catch (error) {
      return _failure('The product could not be saved: $error');
    }
  }

  static Future<ProductLearningResult> saveProduct({
    required Product product,
    required String receiptItemName,
  }) async {
    if (product.name.trim().isEmpty) {
      return _failure('A product name is required.');
    }

    if (product.barcode.trim().isEmpty) {
      return _failure('A product barcode is required.');
    }

    Product savedProduct;

    try {
      // Check the exact barcode and valid equivalent UPC/EAN forms.
      final existingProduct = await ProductService.getProductByBarcode(
        product.barcode,
      );

      if (existingProduct != null) {
        return _failure(
          'This barcode already belongs to ${existingProduct.name} '
          '(${existingProduct.barcode}). '
          'No catalogue details were changed. '
          'Cancel and select the existing product, or check the barcode.',
        );
      }

      // Insert only: never overwrite an existing catalogue row.
      savedProduct = await SupabaseProductService.createProduct(product);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return _failure(
          'A product with this barcode already exists. '
          'No existing catalogue details were changed. '
          'Cancel and select the existing product.',
        );
      }

      return _failure('The product could not be saved: ${error.message}');
    } catch (error) {
      return _failure('The product could not be saved: $error');
    }

    if (receiptItemName.trim().isEmpty) {
      return ProductLearningResult(
        product: savedProduct,
        productSaved: true,
        aliasSaved: false,
        message: '${savedProduct.name} was saved to the catalogue.',
      );
    }

    final aliasSaved = await ProductAliasService.saveAlias(
      alias: receiptItemName,
      product: savedProduct,
    );

    if (!aliasSaved) {
      return ProductLearningResult(
        product: savedProduct,
        productSaved: true,
        aliasSaved: false,
        message:
            '${savedProduct.name} was saved, but the receipt wording '
            'could not be remembered.',
      );
    }

    return ProductLearningResult(
      product: savedProduct,
      productSaved: true,
      aliasSaved: true,
      message:
          '${savedProduct.name} was saved and the receipt wording '
          'was remembered.',
    );
  }

  static ProductLearningResult _failure(String message) {
    return ProductLearningResult(
      product: null,
      productSaved: false,
      aliasSaved: false,
      message: message,
    );
  }
}

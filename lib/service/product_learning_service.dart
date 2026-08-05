import '../models/product.dart';
import '../models/product_suggestion.dart';
import 'product_alias_service.dart';
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
      return const ProductLearningResult(
        product: null,
        productSaved: false,
        aliasSaved: false,
        message: 'A product name and barcode are required.',
      );
    }

    final product = suggestion.toProduct(imageUrl: imageUrl);

    return saveProduct(product: product, receiptItemName: receiptItemName);
  }

  static Future<ProductLearningResult> saveProduct({
    required Product product,
    required String receiptItemName,
  }) async {
    if (product.name.trim().isEmpty) {
      return const ProductLearningResult(
        product: null,
        productSaved: false,
        aliasSaved: false,
        message: 'A product name is required.',
      );
    }

    if (product.barcode.trim().isEmpty) {
      return const ProductLearningResult(
        product: null,
        productSaved: false,
        aliasSaved: false,
        message: 'A product barcode is required.',
      );
    }

    final productSaved = await SupabaseProductService.saveProduct(product);

    if (!productSaved) {
      return const ProductLearningResult(
        product: null,
        productSaved: false,
        aliasSaved: false,
        message: 'The product could not be saved to the catalogue.',
      );
    }

    final aliasSaved = await ProductAliasService.saveAlias(
      alias: receiptItemName,
      product: product,
    );

    if (!aliasSaved) {
      return ProductLearningResult(
        product: product,
        productSaved: true,
        aliasSaved: false,
        message:
            '${product.name} was saved, but the receipt wording could not be remembered.',
      );
    }

    return ProductLearningResult(
      product: product,
      productSaved: true,
      aliasSaved: true,
      message:
          '${product.name} was saved and the receipt wording was remembered.',
    );
  }
}

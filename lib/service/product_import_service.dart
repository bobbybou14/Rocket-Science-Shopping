import '../models/product.dart';
import '../models/product_import_result.dart';

class ProductImportValidationResult {
  final List<Product> products;
  final ProductImportResult report;

  const ProductImportValidationResult({
    required this.products,
    required this.report,
  });
}

class ProductImportService {
  static ProductImportValidationResult validateProducts(
    List<Product> importedProducts,
  ) {
    final validProducts = <Product>[];
    final errors = <ProductImportError>[];
    final seenBarcodes = <String>{};

    var skipped = 0;

    for (var i = 0; i < importedProducts.length; i++) {
      final product = importedProducts[i];
      final row = i + 1;

      final barcode = product.barcode.trim();
      final name = product.name.trim();

      if (barcode.isEmpty) {
        errors.add(
          ProductImportError(
            rowNumber: row,
            message: 'Missing barcode',
            rowData: product.toMap(),
          ),
        );
        continue;
      }

      if (name.isEmpty) {
        errors.add(
          ProductImportError(
            rowNumber: row,
            message: 'Missing product name',
            rowData: product.toMap(),
          ),
        );
        continue;
      }

      if (seenBarcodes.contains(barcode)) {
        skipped++;
        continue;
      }

      seenBarcodes.add(barcode);

      validProducts.add(
        Product(
          barcode: barcode,
          name: name,
          brand: product.brand.trim(),
          category: product.category.trim(),
          size: product.size.trim(),
          imageUrl: product.imageUrl.trim(),
          taxable: product.taxable,
          measurementType: product.measurementType,
          baseUnit: product.baseUnit,
          packageQuantity: product.packageQuantity,
          variableMeasurement: product.variableMeasurement,
        ),
      );
    }

    return ProductImportValidationResult(
      products: validProducts,
      report: ProductImportResult(
        totalRows: importedProducts.length,
        validRows: validProducts.length,
        added: 0,
        updated: 0,
        skipped: skipped,
        failed: errors.length,
        errors: errors,
      ),
    );
  }
}

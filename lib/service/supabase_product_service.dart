import 'package:supabase_flutter/supabase_flutter.dart';

import 'product_service.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/product_import_result.dart';
import 'product_import_service.dart';

class SupabaseProductService {
  static final _client = Supabase.instance.client;

  static Future<List<Product>> getProducts() async {
    try {
      final response = await _client.from('products').select().order('name');

      return response.map<Product>((item) => Product.fromMap(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<CartItem?> findByBarcode(String barcode) async {
    try {
      final product = await ProductService.getProductByBarcode(barcode);

      if (product == null) return null;

      return CartItem(product: product, price: 0.00);
    } catch (_) {
      return null;
    }
  }

  static Future<Product> createProduct(Product product) async {
    if (product.barcode.trim().isEmpty || product.name.trim().isEmpty) {
      throw ArgumentError('A product name and barcode are required.');
    }

    final response = await _client
        .from('products')
        .insert(product.toMap())
        .select()
        .single();

    return Product.fromMap(response);
  }

  static Future<bool> saveProduct(Product product) async {
    if (product.barcode.trim().isEmpty || product.name.trim().isEmpty) {
      return false;
    }

    try {
      await _client
          .from('products')
          .upsert(product.toMap(), onConflict: 'barcode');

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Set<String>> _findExistingImportBarcodes(
    List<Product> products,
  ) async {
    final barcodes = products
        .map((product) => product.barcode.trim())
        .where((barcode) => barcode.isNotEmpty)
        .toSet()
        .toList();

    final existingBarcodes = <String>{};
    const batchSize = 100;

    for (var start = 0; start < barcodes.length; start += batchSize) {
      final end = start + batchSize > barcodes.length
          ? barcodes.length
          : start + batchSize;

      final batch = barcodes.sublist(start, end);

      final response = await _client
          .from('products')
          .select('barcode')
          .inFilter('barcode', batch);

      for (final row in response) {
        final barcode = row['barcode']?.toString().trim() ?? '';

        if (barcode.isNotEmpty) {
          existingBarcodes.add(barcode);
        }
      }
    }

    return existingBarcodes;
  }

  static Future<ProductImportResult> previewProductImport(
    List<Product> importedProducts,
  ) async {
    final validation = ProductImportService.validateProducts(importedProducts);
    final validProducts = validation.products;
    final validationReport = validation.report;

    if (validProducts.isEmpty) {
      return validationReport;
    }

    final existingBarcodes = <String>{};

    try {
      existingBarcodes.addAll(await _findExistingImportBarcodes(validProducts));
    } catch (error) {
      return ProductImportResult(
        totalRows: validationReport.totalRows,
        validRows: validationReport.validRows,
        added: 0,
        updated: 0,
        skipped: validationReport.skipped,
        failed: validationReport.failed + validProducts.length,
        errors: [
          ...validationReport.errors,
          ProductImportError(
            rowNumber: 0,
            message:
                'Unable to compare the import with the existing catalogue: '
                '$error',
            rowData: const {},
          ),
        ],
      );
    }

    var productsToAdd = 0;
    var productsToUpdate = 0;

    for (final product in validProducts) {
      if (existingBarcodes.contains(product.barcode)) {
        productsToUpdate++;
      } else {
        productsToAdd++;
      }
    }

    return ProductImportResult(
      totalRows: validationReport.totalRows,
      validRows: validationReport.validRows,
      added: productsToAdd,
      updated: productsToUpdate,
      skipped: validationReport.skipped,
      failed: validationReport.failed,
      errors: validationReport.errors,
    );
  }

  static Future<ProductImportResult> importProducts(
    List<Product> importedProducts, {
    int batchSize = 500,
  }) async {
    final validation = ProductImportService.validateProducts(importedProducts);
    final validProducts = validation.products;
    final validationReport = validation.report;

    if (validProducts.isEmpty) {
      return validationReport;
    }

    final errors = <ProductImportError>[...validationReport.errors];

    final normalizedBatchSize = batchSize <= 0 ? 500 : batchSize;
    final existingBarcodes = <String>{};

    try {
      existingBarcodes.addAll(await _findExistingImportBarcodes(validProducts));
    } catch (error) {
      return ProductImportResult(
        totalRows: validationReport.totalRows,
        validRows: validationReport.validRows,
        added: 0,
        updated: 0,
        skipped: validationReport.skipped,
        failed: validationReport.failed + validProducts.length,
        errors: [
          ...errors,
          ProductImportError(
            rowNumber: 0,
            message: 'Unable to read the existing product catalogue: $error',
            rowData: const {},
          ),
        ],
      );
    }

    var added = 0;
    var updated = 0;
    var importFailures = 0;

    for (
      var start = 0;
      start < validProducts.length;
      start += normalizedBatchSize
    ) {
      final end = start + normalizedBatchSize > validProducts.length
          ? validProducts.length
          : start + normalizedBatchSize;

      final batch = validProducts.sublist(start, end);

      try {
        await _client
            .from('products')
            .upsert(
              batch.map((product) => product.toMap()).toList(),
              onConflict: 'barcode',
            );

        for (final product in batch) {
          if (existingBarcodes.contains(product.barcode)) {
            updated++;
          } else {
            added++;
            existingBarcodes.add(product.barcode);
          }
        }
      } catch (_) {
        for (var batchIndex = 0; batchIndex < batch.length; batchIndex++) {
          final product = batch[batchIndex];
          final importRowNumber = start + batchIndex + 1;

          try {
            await _client
                .from('products')
                .upsert(product.toMap(), onConflict: 'barcode');

            if (existingBarcodes.contains(product.barcode)) {
              updated++;
            } else {
              added++;
              existingBarcodes.add(product.barcode);
            }
          } catch (error) {
            importFailures++;

            errors.add(
              ProductImportError(
                rowNumber: importRowNumber,
                message: 'Supabase import failed: $error',
                rowData: product.toMap(),
              ),
            );
          }
        }
      }
    }

    return ProductImportResult(
      totalRows: validationReport.totalRows,
      validRows: validationReport.validRows,
      added: added,
      updated: updated,
      skipped: validationReport.skipped,
      failed: validationReport.failed + importFailures,
      errors: errors,
    );
  }
}

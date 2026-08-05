import '../models/measurement_type.dart';
import '../models/measurement_unit.dart';
import '../models/product.dart';
import '../models/product_import_result.dart';
import 'supabase_product_service.dart';

class ProductCsvParseResult {
  final List<Product> products;
  final List<ProductImportError> errors;

  const ProductCsvParseResult({required this.products, required this.errors});

  bool get hasErrors => errors.isNotEmpty;
}

class ProductCsvImportResult {
  final ProductCsvParseResult parseResult;
  final ProductImportResult importResult;

  const ProductCsvImportResult({
    required this.parseResult,
    required this.importResult,
  });
}

class ProductCsvImportService {
  static const List<String> requiredHeaders = ['barcode', 'name'];

  static const List<String> supportedHeaders = [
    'barcode',
    'name',
    'brand',
    'category',
    'size',
    'image_url',
    'taxable',
    'measurement_type',
    'base_unit',
    'package_quantity',
    'variable_measurement',
  ];

  static ProductCsvParseResult parseCsv(String csvText) {
    final normalizedText = csvText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalizedText.isEmpty) {
      return ProductCsvParseResult(
        products: const [],
        errors: [
          const ProductImportError(
            rowNumber: 0,
            message: 'The CSV file is empty.',
            rowData: {},
          ),
        ],
      );
    }

    final rows = _parseRows(normalizedText);

    if (rows.isEmpty) {
      return ProductCsvParseResult(
        products: const [],
        errors: [
          const ProductImportError(
            rowNumber: 0,
            message: 'No CSV rows could be read.',
            rowData: {},
          ),
        ],
      );
    }

    final headers = rows.first.map(_normalizeHeader).toList(growable: false);

    final errors = <ProductImportError>[];

    for (final requiredHeader in requiredHeaders) {
      if (!headers.contains(requiredHeader)) {
        errors.add(
          ProductImportError(
            rowNumber: 1,
            message: 'Missing required CSV column: $requiredHeader',
            rowData: {'headers': headers},
          ),
        );
      }
    }

    if (errors.isNotEmpty) {
      return ProductCsvParseResult(products: const [], errors: errors);
    }

    final products = <Product>[];

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final csvRowNumber = rowIndex + 1;
      final values = rows[rowIndex];

      if (_isBlankRow(values)) {
        continue;
      }

      final rowData = <String, dynamic>{};

      for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
        final header = headers[columnIndex];

        if (header.isEmpty) {
          continue;
        }

        final value = columnIndex < values.length
            ? values[columnIndex].trim()
            : '';

        rowData[header] = value;
      }

      final barcode = _readValue(rowData, 'barcode');
      final name = _readValue(rowData, 'name');

      if (barcode.isEmpty) {
        errors.add(
          ProductImportError(
            rowNumber: csvRowNumber,
            message: 'Missing barcode.',
            rowData: rowData,
          ),
        );
        continue;
      }

      if (name.isEmpty) {
        errors.add(
          ProductImportError(
            rowNumber: csvRowNumber,
            message: 'Missing product name.',
            rowData: rowData,
          ),
        );
        continue;
      }

      final packageQuantityText = _readValue(rowData, 'package_quantity');

      final packageQuantity = packageQuantityText.isEmpty
          ? null
          : double.tryParse(packageQuantityText);

      if (packageQuantityText.isNotEmpty && packageQuantity == null) {
        errors.add(
          ProductImportError(
            rowNumber: csvRowNumber,
            message: 'Invalid package quantity: $packageQuantityText',
            rowData: rowData,
          ),
        );
        continue;
      }

      products.add(
        Product(
          barcode: barcode,
          name: name,
          brand: _readValue(rowData, 'brand'),
          category: _readValue(rowData, 'category'),
          size: _readValue(rowData, 'size'),
          imageUrl: _readValue(rowData, 'image_url'),
          taxable: _parseBoolean(_readValue(rowData, 'taxable')),
          measurementType: MeasurementType.fromDatabase(
            _readValue(rowData, 'measurement_type'),
          ),
          baseUnit: MeasurementUnit.fromDatabase(
            _readValue(rowData, 'base_unit'),
          ),
          packageQuantity: packageQuantity,
          variableMeasurement: _parseBoolean(
            _readValue(rowData, 'variable_measurement'),
          ),
        ),
      );
    }

    return ProductCsvParseResult(products: products, errors: errors);
  }

  static Future<ProductCsvImportResult> importCsv(
    String csvText, {
    int batchSize = 500,
  }) async {
    final parseResult = parseCsv(csvText);

    if (parseResult.products.isEmpty) {
      return ProductCsvImportResult(
        parseResult: parseResult,
        importResult: ProductImportResult(
          totalRows: parseResult.errors.length,
          validRows: 0,
          added: 0,
          updated: 0,
          skipped: 0,
          failed: parseResult.errors.length,
          errors: parseResult.errors,
        ),
      );
    }

    final databaseResult = await SupabaseProductService.importProducts(
      parseResult.products,
      batchSize: batchSize,
    );

    return ProductCsvImportResult(
      parseResult: parseResult,
      importResult: ProductImportResult(
        totalRows: databaseResult.totalRows + parseResult.errors.length,
        validRows: databaseResult.validRows,
        added: databaseResult.added,
        updated: databaseResult.updated,
        skipped: databaseResult.skipped,
        failed: databaseResult.failed + parseResult.errors.length,
        errors: [...parseResult.errors, ...databaseResult.errors],
      ),
    );
  }

  static List<List<String>> _parseRows(String csvText) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    var currentValue = StringBuffer();
    var insideQuotes = false;

    for (var index = 0; index < csvText.length; index++) {
      final character = csvText[index];

      if (character == '"') {
        final nextIsQuote =
            insideQuotes &&
            index + 1 < csvText.length &&
            csvText[index + 1] == '"';

        if (nextIsQuote) {
          currentValue.write('"');
          index++;
        } else {
          insideQuotes = !insideQuotes;
        }

        continue;
      }

      if (character == ',' && !insideQuotes) {
        currentRow.add(currentValue.toString());
        currentValue = StringBuffer();
        continue;
      }

      if (character == '\n' && !insideQuotes) {
        currentRow.add(currentValue.toString());
        rows.add(currentRow);

        currentRow = <String>[];
        currentValue = StringBuffer();
        continue;
      }

      currentValue.write(character);
    }

    currentRow.add(currentValue.toString());

    if (!_isBlankRow(currentRow)) {
      rows.add(currentRow);
    }

    return rows;
  }

  static String _normalizeHeader(String value) {
    return value
        .replaceFirst('\ufeff', '')
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
  }

  static String _readValue(Map<String, dynamic> row, String key) {
    return row[key]?.toString().trim() ?? '';
  }

  static bool _parseBoolean(String value) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
        return true;
      default:
        return false;
    }
  }

  static bool _isBlankRow(List<String> row) {
    return row.every((value) => value.trim().isEmpty);
  }
}

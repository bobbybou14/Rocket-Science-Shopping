import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const int targetProductCount = 500;
const int productsPerPage = 100;
const int maximumAttempts = 5;
const Duration delayBetweenPages = Duration(seconds: 3);

Future<void> main(List<String> arguments) async {
  final outputPath = arguments.isNotEmpty
      ? arguments.first
      : 'assets/catalogues/shopping_seed_500.csv';

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);

  stdout.writeln('Downloading up to $targetProductCount Canadian products...');

  final rawProducts = <dynamic>[];

  var page = 1;

  while (rawProducts.length < targetProductCount) {
    stdout.writeln(
      'Requesting page $page '
      '(${rawProducts.length}/$targetProductCount products received)...',
    );

    final pageProducts = await _downloadProductPage(page);

    if (pageProducts == null) {
      stderr.writeln(
        'Open Food Facts could not provide page $page after '
        '$maximumAttempts attempts.',
      );
      stderr.writeln(
        'No CSV was created. Wait a few minutes and run the script again.',
      );

      exitCode = 1;
      return;
    }

    if (pageProducts.isEmpty) {
      stdout.writeln('Open Food Facts returned no additional products.');
      break;
    }

    rawProducts.addAll(pageProducts);

    if (pageProducts.length < productsPerPage) {
      break;
    }

    page++;

    await Future<void>.delayed(delayBetweenPages);
  }

  final catalogueRows = <CatalogueRow>[];
  final seenBarcodes = <String>{};

  var missingBarcode = 0;
  var missingName = 0;
  var duplicates = 0;

  for (final rawProduct in rawProducts) {
    if (rawProduct is! Map) {
      continue;
    }

    final product = Map<String, dynamic>.from(rawProduct);

    final barcode = _cleanBarcode(product['code']);

    if (barcode.isEmpty) {
      missingBarcode++;
      continue;
    }

    if (!seenBarcodes.add(barcode)) {
      duplicates++;
      continue;
    }

    final productName = _firstNonEmpty([
      product['product_name_en'],
      product['product_name'],
    ]);

    if (productName.isEmpty) {
      missingName++;
      continue;
    }

    final categories = _readStringList(product['categories_tags_en']);

    final quantityDetails = _parseQuantity(
      quantityText: _stringValue(product['quantity']),
      numericQuantity: product['product_quantity'],
      quantityUnit: _stringValue(product['product_quantity_unit']),
    );

    catalogueRows.add(
      CatalogueRow(
        barcode: barcode,
        name: _cleanText(productName),
        brand: _cleanText(_stringValue(product['brands'])),
        category: _suggestCategory(categories),
        size: _cleanText(_stringValue(product['quantity'])),
        imageUrl: _stringValue(product['image_front_url']),
        taxable: _suggestTaxable(categories),
        measurementType: quantityDetails.measurementType,
        baseUnit: quantityDetails.baseUnit,
        packageQuantity: quantityDetails.packageQuantity,
        variableMeasurement: false,
        source: 'Open Food Facts',
        requiresTaxReview: true,
      ),
    );

    if (catalogueRows.length >= targetProductCount) {
      break;
    }
  }

  catalogueRows.sort((a, b) {
    final categoryComparison = a.category.compareTo(b.category);

    if (categoryComparison != 0) {
      return categoryComparison;
    }

    return a.name.compareTo(b.name);
  });

  final csv = StringBuffer();

  csv.writeln(
    [
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
      'source',
      'requires_tax_review',
    ].map(_csvValue).join(','),
  );

  for (final row in catalogueRows) {
    csv.writeln(
      [
        row.barcode,
        row.name,
        row.brand,
        row.category,
        row.size,
        row.imageUrl,
        row.taxable,
        row.measurementType,
        row.baseUnit,
        row.packageQuantity ?? '',
        row.variableMeasurement,
        row.source,
        row.requiresTaxReview,
      ].map(_csvValue).join(','),
    );
  }

  await outputFile.writeAsString(csv.toString(), encoding: utf8);

  stdout.writeln('');
  stdout.writeln('Seed catalogue created successfully.');
  stdout.writeln('Output: ${outputFile.path}');
  stdout.writeln('Products written: ${catalogueRows.length}');
  stdout.writeln('Missing barcode: $missingBarcode');
  stdout.writeln('Missing name: $missingName');
  stdout.writeln('Duplicate barcode: $duplicates');
  stdout.writeln('');
  stdout.writeln(
    'Every imported tax value should be reviewed before production use.',
  );
}

Future<List<dynamic>?> _downloadProductPage(int page) async {
  final uri = Uri.https('world.openfoodfacts.org', '/api/v2/search', {
    'countries_tags_en': 'Canada',
    'page': page.toString(),
    'page_size': productsPerPage.toString(),
    'sort_by': 'unique_scans_n',
    'fields': [
      'code',
      'product_name',
      'product_name_en',
      'brands',
      'categories',
      'categories_tags_en',
      'quantity',
      'image_front_url',
      'product_quantity',
      'product_quantity_unit',
    ].join(','),
  });

  for (var attempt = 1; attempt <= maximumAttempts; attempt++) {
    try {
      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'RocketScienceShopping/1.0 catalogue-bootstrap '
                  '(contact: rocket-science-shopping)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          stderr.writeln('Page $page returned an unexpected JSON response.');
          return null;
        }

        final products = decoded['products'];

        if (products is! List) {
          stderr.writeln('Page $page did not contain a product list.');
          return null;
        }

        return products;
      }

      final retryableStatus =
          response.statusCode == 429 ||
          response.statusCode == 500 ||
          response.statusCode == 502 ||
          response.statusCode == 503 ||
          response.statusCode == 504;

      stderr.writeln(
        'Page $page attempt $attempt returned '
        'HTTP ${response.statusCode}.',
      );

      if (!retryableStatus) {
        return null;
      }
    } catch (error) {
      stderr.writeln('Page $page attempt $attempt failed: $error');
    }

    if (attempt < maximumAttempts) {
      final retryDelay = Duration(seconds: attempt * 10);

      stdout.writeln(
        'Waiting ${retryDelay.inSeconds} seconds before retrying...',
      );

      await Future<void>.delayed(retryDelay);
    }
  }

  return null;
}

class CatalogueRow {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String size;
  final String imageUrl;
  final bool taxable;
  final String measurementType;
  final String baseUnit;
  final double? packageQuantity;
  final bool variableMeasurement;
  final String source;
  final bool requiresTaxReview;

  const CatalogueRow({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.category,
    required this.size,
    required this.imageUrl,
    required this.taxable,
    required this.measurementType,
    required this.baseUnit,
    required this.packageQuantity,
    required this.variableMeasurement,
    required this.source,
    required this.requiresTaxReview,
  });
}

class QuantityDetails {
  final String measurementType;
  final String baseUnit;
  final double? packageQuantity;

  const QuantityDetails({
    required this.measurementType,
    required this.baseUnit,
    required this.packageQuantity,
  });
}

QuantityDetails _parseQuantity({
  required String quantityText,
  required dynamic numericQuantity,
  required String quantityUnit,
}) {
  var quantity = _toDouble(numericQuantity);
  var unit = quantityUnit.trim().toLowerCase();

  if (quantity == null || unit.isEmpty) {
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(kg|g|mg|l|ml|cl|oz|lb|lbs)\b',
      caseSensitive: false,
    ).firstMatch(quantityText);

    if (match != null) {
      quantity = double.tryParse(match.group(1)!.replaceAll(',', '.'));

      unit = match.group(2)!.toLowerCase();
    }
  }

  switch (unit) {
    case 'kg':
      return QuantityDetails(
        measurementType: 'weight',
        baseUnit: 'kg',
        packageQuantity: quantity,
      );

    case 'g':
    case 'mg':
      return QuantityDetails(
        measurementType: 'weight',
        baseUnit: 'g',
        packageQuantity: unit == 'mg' && quantity != null
            ? quantity / 1000
            : quantity,
      );

    case 'lb':
    case 'lbs':
      return QuantityDetails(
        measurementType: 'weight',
        baseUnit: 'kg',
        packageQuantity: quantity == null ? null : quantity * 0.45359237,
      );

    case 'l':
      return QuantityDetails(
        measurementType: 'volume',
        baseUnit: 'l',
        packageQuantity: quantity,
      );

    case 'ml':
    case 'cl':
      return QuantityDetails(
        measurementType: 'volume',
        baseUnit: 'ml',
        packageQuantity: unit == 'cl' && quantity != null
            ? quantity * 10
            : quantity,
      );

    case 'oz':
      return QuantityDetails(
        measurementType: 'weight',
        baseUnit: 'g',
        packageQuantity: quantity == null ? null : quantity * 28.349523125,
      );

    default:
      return const QuantityDetails(
        measurementType: 'each',
        baseUnit: 'each',
        packageQuantity: null,
      );
  }
}

String _suggestCategory(List<String> categories) {
  final text = categories.join(' ').toLowerCase();

  if (_containsAny(text, ['milk', 'cheese', 'yogurt', 'dairy', 'butter'])) {
    return 'Dairy';
  }

  if (_containsAny(text, ['bread', 'bakery', 'buns', 'bagels', 'pastries'])) {
    return 'Bakery';
  }

  if (_containsAny(text, ['fruit', 'vegetable', 'produce'])) {
    return 'Produce';
  }

  if (_containsAny(text, ['meat', 'beef', 'pork', 'chicken', 'turkey'])) {
    return 'Meat & Poultry';
  }

  if (_containsAny(text, ['fish', 'seafood'])) {
    return 'Seafood';
  }

  if (_containsAny(text, ['frozen', 'ice cream'])) {
    return 'Frozen';
  }

  if (_containsAny(text, ['cereal', 'breakfast'])) {
    return 'Breakfast';
  }

  if (_containsAny(text, ['beverage', 'drink', 'juice', 'water', 'coffee'])) {
    return 'Beverages';
  }

  if (_containsAny(text, ['snack', 'chips', 'candy', 'chocolate', 'cookies'])) {
    return 'Snacks';
  }

  if (_containsAny(text, ['sauce', 'pasta', 'rice', 'canned', 'condiment'])) {
    return 'Pantry';
  }

  if (_containsAny(text, ['baby', 'infant'])) {
    return 'Baby';
  }

  if (_containsAny(text, ['pet', 'dog', 'cat'])) {
    return 'Pet';
  }

  return 'Grocery';
}

bool _suggestTaxable(List<String> categories) {
  final text = categories.join(' ').toLowerCase();

  return _containsAny(text, [
    'candy',
    'candies',
    'chocolate',
    'chips',
    'snack',
    'soft drink',
    'soda',
    'carbonated',
    'energy drink',
  ]);
}

bool _containsAny(String text, List<String> values) {
  return values.any(text.contains);
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value.map(_stringValue).where((item) => item.isNotEmpty).toList();
  }

  final text = _stringValue(value);

  if (text.isEmpty) {
    return const [];
  }

  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _cleanBarcode(dynamic value) {
  return _stringValue(value).replaceAll(RegExp(r'[^0-9]'), '');
}

String _cleanText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').replaceAll('\u00a0', ' ').trim();
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _stringValue(value);

    if (text.isNotEmpty) {
      return text;
    }
  }

  return '';
}

String _stringValue(dynamic value) {
  return value?.toString().trim() ?? '';
}

double? _toDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString().replaceAll(',', '.'));
}

String _csvValue(dynamic value) {
  final text = value?.toString() ?? '';

  if (!text.contains(',') &&
      !text.contains('"') &&
      !text.contains('\n') &&
      !text.contains('\r')) {
    return text;
  }

  return '"${text.replaceAll('"', '""')}"';
}

import 'receipt_cleanup_service.dart';

class InterpretedReceiptLine {
  final String rawText;
  final String cleanedText;
  final String barcode;
  final String brand;
  final String description;
  final double? packageQuantity;
  final String packageUnit;
  final List<String> meaningfulTokens;

  const InterpretedReceiptLine({
    required this.rawText,
    required this.cleanedText,
    required this.barcode,
    required this.brand,
    required this.description,
    required this.packageQuantity,
    required this.packageUnit,
    required this.meaningfulTokens,
  });

  bool get hasBarcode => barcode.isNotEmpty;

  bool get hasBrand => brand.isNotEmpty;

  bool get hasDescription => description.isNotEmpty;

  bool get hasPackageInformation {
    return packageQuantity != null && packageUnit.isNotEmpty;
  }
}

class ReceiptLineInterpreterService {
  ReceiptLineInterpreterService._();

  static const Map<String, String> _knownBrands = {
    'GREAT VALUE': 'Great Value',
    'NO NAME': 'No Name',
    'PRESIDENTS CHOICE': 'President\'s Choice',
    'DR PEPPER': 'Dr Pepper',
    'COCA COLA': 'Coca-Cola',
    'RED BULL': 'Red Bull',
  };

  static const Set<String> _packageUnits = {
    'PK',
    'PACK',
    'CT',
    'COUNT',
    'EA',
    'EACH',
    'GAL',
    'L',
    'ML',
    'KG',
    'G',
    'LB',
    'OZ',
  };

  static const Set<String> _nonDescriptionTokens = {'F', 'N', 'X', 'O'};

  static InterpretedReceiptLine interpret(String rawText) {
    final barcode = _extractBarcode(rawText);
    final cleanedText = ReceiptCleanupService.clean(rawText);

    final tokens = cleanedText
        .split(RegExp(r'\s+'))
        .map((token) => token.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList();

    final brandMatch = _detectBrand(tokens);
    final packageDetails = _extractPackageDetails(tokens);

    final excludedIndexes = <int>{
      ...brandMatch.tokenIndexes,
      ...packageDetails.tokenIndexes,
    };

    final meaningfulTokens = <String>[];

    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];

      if (excludedIndexes.contains(index)) {
        continue;
      }

      if (_nonDescriptionTokens.contains(token)) {
        continue;
      }

      if (RegExp(r'^\d+$').hasMatch(token)) {
        continue;
      }

      meaningfulTokens.add(token);
    }

    return InterpretedReceiptLine(
      rawText: rawText,
      cleanedText: cleanedText,
      barcode: barcode,
      brand: brandMatch.brand,
      description: meaningfulTokens.join(' '),
      packageQuantity: packageDetails.quantity,
      packageUnit: packageDetails.unit,
      meaningfulTokens: meaningfulTokens,
    );
  }

  static String _extractBarcode(String value) {
    final matches = RegExp(r'\b\d{8,14}\b').allMatches(value);

    for (final match in matches) {
      final barcode = match.group(0);

      if (barcode != null && barcode.isNotEmpty) {
        return barcode;
      }
    }

    return '';
  }

  static _BrandMatch _detectBrand(List<String> tokens) {
    if (tokens.isEmpty) {
      return const _BrandMatch(brand: '', tokenIndexes: {});
    }

    for (final entry in _knownBrands.entries) {
      final brandTokens = entry.key.split(' ');

      if (brandTokens.length > tokens.length) {
        continue;
      }

      for (
        var startIndex = 0;
        startIndex <= tokens.length - brandTokens.length;
        startIndex++
      ) {
        var matches = true;

        for (var offset = 0; offset < brandTokens.length; offset++) {
          if (tokens[startIndex + offset] != brandTokens[offset]) {
            matches = false;
            break;
          }
        }

        if (!matches) {
          continue;
        }

        return _BrandMatch(
          brand: entry.value,
          tokenIndexes: {
            for (
              var index = startIndex;
              index < startIndex + brandTokens.length;
              index++
            )
              index,
          },
        );
      }
    }

    return const _BrandMatch(brand: '', tokenIndexes: {});
  }

  static _PackageDetails _extractPackageDetails(List<String> tokens) {
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];

      final combinedMatch = RegExp(
        r'^(\d+(?:\.\d+)?)(PK|PACK|CT|GAL|L|ML|KG|G|LB|OZ)$',
      ).firstMatch(token);

      if (combinedMatch != null) {
        return _PackageDetails(
          quantity: double.tryParse(combinedMatch.group(1) ?? ''),
          unit: combinedMatch.group(2) ?? '',
          tokenIndexes: {index},
        );
      }

      if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(token)) {
        continue;
      }

      if (index + 1 >= tokens.length) {
        continue;
      }

      final nextToken = tokens[index + 1];

      if (!_packageUnits.contains(nextToken)) {
        continue;
      }

      return _PackageDetails(
        quantity: double.tryParse(token),
        unit: nextToken,
        tokenIndexes: {index, index + 1},
      );
    }

    return const _PackageDetails(quantity: null, unit: '', tokenIndexes: {});
  }
}

class _BrandMatch {
  final String brand;
  final Set<int> tokenIndexes;

  const _BrandMatch({required this.brand, required this.tokenIndexes});
}

class _PackageDetails {
  final double? quantity;
  final String unit;
  final Set<int> tokenIndexes;

  const _PackageDetails({
    required this.quantity,
    required this.unit,
    required this.tokenIndexes,
  });
}

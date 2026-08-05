import 'measurement_type.dart';
import 'measurement_unit.dart';
import 'product.dart';

class ProductSuggestion {
  final String sourceReceiptName;
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String size;
  final bool taxable;
  final MeasurementType measurementType;
  final MeasurementUnit baseUnit;
  final double? packageQuantity;
  final bool variableMeasurement;
  final double confidenceScore;
  final List<String> reasons;

  const ProductSuggestion({
    required this.sourceReceiptName,
    required this.name,
    this.barcode = '',
    this.brand = '',
    this.category = '',
    this.size = '',
    this.taxable = false,
    this.measurementType = MeasurementType.each,
    this.baseUnit = MeasurementUnit.each,
    this.packageQuantity,
    this.variableMeasurement = false,
    this.confidenceScore = 0,
    this.reasons = const [],
  });

  bool get hasBarcode => barcode.trim().isNotEmpty;

  bool get hasUsableName => name.trim().isNotEmpty;

  bool get isReadyToSave => hasBarcode && hasUsableName;

  Product toProduct({String imageUrl = ''}) {
    return Product(
      barcode: barcode.trim(),
      name: name.trim(),
      brand: brand.trim(),
      category: category.trim(),
      size: size.trim(),
      imageUrl: imageUrl.trim(),
      taxable: taxable,
      measurementType: measurementType,
      baseUnit: baseUnit,
      packageQuantity: packageQuantity,
      variableMeasurement: variableMeasurement,
    );
  }

  ProductSuggestion copyWith({
    String? sourceReceiptName,
    String? barcode,
    String? name,
    String? brand,
    String? category,
    String? size,
    bool? taxable,
    MeasurementType? measurementType,
    MeasurementUnit? baseUnit,
    double? packageQuantity,
    bool clearPackageQuantity = false,
    bool? variableMeasurement,
    double? confidenceScore,
    List<String>? reasons,
  }) {
    return ProductSuggestion(
      sourceReceiptName: sourceReceiptName ?? this.sourceReceiptName,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      size: size ?? this.size,
      taxable: taxable ?? this.taxable,
      measurementType: measurementType ?? this.measurementType,
      baseUnit: baseUnit ?? this.baseUnit,
      packageQuantity: clearPackageQuantity
          ? null
          : packageQuantity ?? this.packageQuantity,
      variableMeasurement: variableMeasurement ?? this.variableMeasurement,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      reasons: reasons ?? this.reasons,
    );
  }
}

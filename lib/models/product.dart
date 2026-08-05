import 'measurement_type.dart';
import 'measurement_unit.dart';

class Product {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String size;
  final String imageUrl;
  final bool taxable;

  // Measurement
  final MeasurementType measurementType;
  final MeasurementUnit baseUnit;
  final double? packageQuantity;
  final bool variableMeasurement;

  const Product({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.category = '',
    this.size = '',
    this.imageUrl = '',
    this.taxable = false,
    this.measurementType = MeasurementType.each,
    this.baseUnit = MeasurementUnit.each,
    this.packageQuantity,
    this.variableMeasurement = false,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      barcode: map['barcode'] ?? '',
      name: map['name'] ?? 'Unknown Product',
      brand: map['brand'] ?? '',
      category: map['category'] ?? '',
      size: map['size'] ?? '',
      imageUrl: map['image_url'] ?? '',
      taxable: map['taxable'] ?? false,
      measurementType: MeasurementType.fromDatabase(map['measurement_type']),
      baseUnit: MeasurementUnit.fromDatabase(map['base_unit']),
      packageQuantity: _toDouble(map['package_quantity']),
      variableMeasurement: map['variable_measurement'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'category': category,
      'size': size,
      'image_url': imageUrl,
      'taxable': taxable,
      'measurement_type': measurementType.databaseValue,
      'base_unit': baseUnit.databaseValue,
      'package_quantity': packageQuantity,
      'variable_measurement': variableMeasurement,
    };
  }

  bool get isEach => measurementType == MeasurementType.each;

  bool get isWeight => measurementType == MeasurementType.weight;

  bool get isVolume => measurementType == MeasurementType.volume;

  bool get hasPackageQuantity =>
      packageQuantity != null && packageQuantity! > 0;

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}

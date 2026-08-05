import '../models/measurement_type.dart';
import '../models/measurement_unit.dart';
import '../models/price.dart';
import '../models/product.dart';
import 'unit_conversion_service.dart';

class PriceCalculationService {
  const PriceCalculationService._();

  /// Creates a complete Price object using the product's measurement metadata.
  ///
  /// Fixed-size products are normalized automatically:
  ///
  /// 454 g for $6.49 -> $14.30/kg
  ///
  /// 2 L for $5.99 -> $3.00/L
  ///
  /// Variable-weight products require an explicit measured quantity and unit
  /// before they can be normalized accurately.
  static Price createPrice({
    required Product product,
    required double price,
    required String store,
    String id = '',
    String? storeId,
    String province = '',
    String city = '',
    String currency = 'CAD',
    String source = 'manual',
    String? receiptId,
    String notes = '',
    MeasurementUnit? advertisedUnit,
    double? measurementQuantity,
    MeasurementUnit? normalizedUnit,
    bool isSale = false,
    double? regularPrice,
    DateTime? saleStartDate,
    DateTime? saleEndDate,
    String? promotionType,
    DateTime? createdAt,
  }) {
    final validationError = validatePrice(
      price: price,
      regularPrice: regularPrice,
      isSale: isSale,
      measurementQuantity: measurementQuantity,
    );

    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final resolvedAdvertisedUnit = advertisedUnit ?? product.baseUnit;

    final resolvedMeasurementQuantity = _resolveMeasurementQuantity(
      product: product,
      suppliedQuantity: measurementQuantity,
    );

    final resolvedNormalizedUnit =
        normalizedUnit ?? determineNormalizedUnit(product.measurementType);

    final normalizedPrice = calculateNormalizedUnitPrice(
      price: price,
      advertisedUnit: resolvedAdvertisedUnit,
      measurementQuantity: resolvedMeasurementQuantity,
      normalizedUnit: resolvedNormalizedUnit,
      variableMeasurement: product.variableMeasurement,
      explicitQuantityProvided: measurementQuantity != null,
    );

    return Price(
      id: id,
      barcode: product.barcode,
      storeId: storeId,
      store: store.trim(),
      province: province.trim(),
      city: city.trim(),
      price: price,
      currency: currency.trim().isEmpty ? 'CAD' : currency.trim(),
      source: source.trim().isEmpty ? 'manual' : source.trim(),
      receiptId: receiptId,
      notes: notes.trim(),
      advertisedUnit: resolvedAdvertisedUnit,
      measurementQuantity: resolvedMeasurementQuantity,
      normalizedUnit: resolvedNormalizedUnit,
      normalizedUnitPrice: normalizedPrice,
      isSale: isSale,
      regularPrice: regularPrice,
      saleStartDate: saleStartDate,
      saleEndDate: saleEndDate,
      promotionType: _nullableTrimmedString(promotionType),
      createdAt: createdAt,
    );
  }

  /// Selects the standard comparison unit for a measurement type.
  static MeasurementUnit determineNormalizedUnit(
    MeasurementType measurementType,
  ) {
    switch (measurementType) {
      case MeasurementType.each:
        return MeasurementUnit.each;

      case MeasurementType.weight:
        return MeasurementUnit.kilogram;

      case MeasurementType.volume:
        return MeasurementUnit.litre;
    }
  }

  /// Calculates a normalized unit price.
  ///
  /// Returns null when the supplied measurement cannot be safely normalized.
  static double? calculateNormalizedUnitPrice({
    required double price,
    required MeasurementUnit advertisedUnit,
    required double measurementQuantity,
    required MeasurementUnit normalizedUnit,
    bool variableMeasurement = false,
    bool explicitQuantityProvided = true,
  }) {
    if (price <= 0 || measurementQuantity <= 0) {
      return null;
    }

    if (variableMeasurement && !explicitQuantityProvided) {
      return null;
    }

    if (advertisedUnit.measurementType != normalizedUnit.measurementType) {
      return null;
    }

    try {
      return UnitConversionService.normalizeUnitPrice(
        totalPrice: price,
        quantity: measurementQuantity,
        advertisedUnit: advertisedUnit,
        normalizedUnit: normalizedUnit,
      );
    } on UnsupportedError {
      return null;
    }
  }

  /// Returns the savings amount between a regular and sale price.
  static double calculateSavings({
    required double price,
    double? regularPrice,
  }) {
    if (regularPrice == null || regularPrice <= 0 || regularPrice <= price) {
      return 0;
    }

    return regularPrice - price;
  }

  /// Returns the percentage saved compared with the regular price.
  static double calculateSavingsPercentage({
    required double price,
    double? regularPrice,
  }) {
    if (regularPrice == null || regularPrice <= 0) {
      return 0;
    }

    final savings = calculateSavings(price: price, regularPrice: regularPrice);

    return (savings / regularPrice) * 100;
  }

  /// Validates the core pricing values.
  ///
  /// Returns null when valid, otherwise returns a readable error message.
  static String? validatePrice({
    required double price,
    double? regularPrice,
    bool isSale = false,
    double? measurementQuantity,
  }) {
    if (!price.isFinite || price <= 0) {
      return 'Price must be a finite value greater than zero.';
    }

    if (measurementQuantity != null &&
        (!measurementQuantity.isFinite || measurementQuantity <= 0)) {
      return 'Measurement quantity must be a finite value greater than zero.';
    }

    if (regularPrice != null && (!regularPrice.isFinite || regularPrice <= 0)) {
      return 'Regular price must be a finite value greater than zero.';
    }

    if (isSale && regularPrice != null && regularPrice <= price) {
      return 'A sale price must be lower than its regular price.';
    }

    return null;
  }

  static double _resolveMeasurementQuantity({
    required Product product,
    required double? suppliedQuantity,
  }) {
    if (suppliedQuantity != null && suppliedQuantity > 0) {
      return suppliedQuantity;
    }

    if (!product.variableMeasurement &&
        product.packageQuantity != null &&
        product.packageQuantity! > 0) {
      return product.packageQuantity!;
    }

    return 1;
  }

  static String? _nullableTrimmedString(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}

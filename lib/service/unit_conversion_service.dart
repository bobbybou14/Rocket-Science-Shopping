import '../models/measurement_unit.dart';

class UnitConversionService {
  const UnitConversionService._();

  static double convert({
    required double value,
    required MeasurementUnit from,
    required MeasurementUnit to,
  }) {
    if (from == to) {
      return value;
    }

    // Weight conversions (base = kilograms)
    if (from.isWeight && to.isWeight) {
      final kilograms = switch (from) {
        MeasurementUnit.gram => value / 1000,
        MeasurementUnit.kilogram => value,
        MeasurementUnit.ounce => value * 0.028349523125,
        MeasurementUnit.pound => value * 0.45359237,
        _ => throw UnsupportedError('Invalid weight unit'),
      };

      return switch (to) {
        MeasurementUnit.gram => kilograms * 1000,
        MeasurementUnit.kilogram => kilograms,
        MeasurementUnit.ounce => kilograms / 0.028349523125,
        MeasurementUnit.pound => kilograms / 0.45359237,
        _ => throw UnsupportedError('Invalid weight unit'),
      };
    }

    // Volume conversions (base = litres)
    if (from.isVolume && to.isVolume) {
      final litres = switch (from) {
        MeasurementUnit.millilitre => value / 1000,
        MeasurementUnit.litre => value,
        _ => throw UnsupportedError('Invalid volume unit'),
      };

      return switch (to) {
        MeasurementUnit.millilitre => litres * 1000,
        MeasurementUnit.litre => litres,
        _ => throw UnsupportedError('Invalid volume unit'),
      };
    }

    throw UnsupportedError(
      'Cannot convert ${from.databaseValue} to ${to.databaseValue}',
    );
  }

  static double normalizeUnitPrice({
    required double totalPrice,
    required double quantity,
    required MeasurementUnit advertisedUnit,
    required MeasurementUnit normalizedUnit,
  }) {
    if (quantity <= 0) {
      return totalPrice;
    }

    final convertedQuantity = convert(
      value: quantity,
      from: advertisedUnit,
      to: normalizedUnit,
    );

    if (convertedQuantity <= 0) {
      return totalPrice;
    }

    return totalPrice / convertedQuantity;
  }
}

import 'measurement_type.dart';

enum MeasurementUnit {
  each,
  package,
  gram,
  kilogram,
  ounce,
  pound,
  millilitre,
  litre;

  String get databaseValue {
    switch (this) {
      case MeasurementUnit.each:
        return 'each';

      case MeasurementUnit.package:
        return 'package';

      case MeasurementUnit.gram:
        return 'g';

      case MeasurementUnit.kilogram:
        return 'kg';

      case MeasurementUnit.ounce:
        return 'oz';

      case MeasurementUnit.pound:
        return 'lb';

      case MeasurementUnit.millilitre:
        return 'ml';

      case MeasurementUnit.litre:
        return 'l';
    }
  }

  String get symbol => databaseValue;

  MeasurementType get measurementType {
    switch (this) {
      case MeasurementUnit.each:
      case MeasurementUnit.package:
        return MeasurementType.each;

      case MeasurementUnit.gram:
      case MeasurementUnit.kilogram:
      case MeasurementUnit.ounce:
      case MeasurementUnit.pound:
        return MeasurementType.weight;

      case MeasurementUnit.millilitre:
      case MeasurementUnit.litre:
        return MeasurementType.volume;
    }
  }

  bool get isWeight => measurementType == MeasurementType.weight;

  bool get isVolume => measurementType == MeasurementType.volume;

  bool get isEach => measurementType == MeasurementType.each;

  static MeasurementUnit fromDatabase(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'package':
        return MeasurementUnit.package;

      case 'g':
        return MeasurementUnit.gram;

      case 'kg':
        return MeasurementUnit.kilogram;

      case 'oz':
        return MeasurementUnit.ounce;

      case 'lb':
        return MeasurementUnit.pound;

      case 'ml':
        return MeasurementUnit.millilitre;

      case 'l':
        return MeasurementUnit.litre;

      default:
        return MeasurementUnit.each;
    }
  }
}

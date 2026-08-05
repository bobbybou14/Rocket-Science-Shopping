enum MeasurementType {
  each,
  weight,
  volume;

  String get databaseValue {
    switch (this) {
      case MeasurementType.each:
        return 'each';
      case MeasurementType.weight:
        return 'weight';
      case MeasurementType.volume:
        return 'volume';
    }
  }

  String get displayName {
    switch (this) {
      case MeasurementType.each:
        return 'Each';
      case MeasurementType.weight:
        return 'Weight';
      case MeasurementType.volume:
        return 'Volume';
    }
  }

  static MeasurementType fromDatabase(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'weight':
        return MeasurementType.weight;

      case 'volume':
        return MeasurementType.volume;

      default:
        return MeasurementType.each;
    }
  }
}

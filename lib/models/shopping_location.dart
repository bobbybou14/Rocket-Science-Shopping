class ShoppingLocation {
  final String city;
  final String province;
  final String postalCode;
  final double radiusKm;
  final double? latitude;
  final double? longitude;

  const ShoppingLocation({
    required this.city,
    required this.province,
    required this.postalCode,
    required this.radiusKm,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates {
    return latitude != null && longitude != null;
  }

  bool get isConfigured {
    return city.trim().isNotEmpty && province.trim().isNotEmpty;
  }

  String get displayName {
    final parts = [
      city.trim(),
      province.trim(),
    ].where((value) => value.isNotEmpty).toList();

    return parts.isEmpty ? 'Shopping area not set' : parts.join(', ');
  }

  ShoppingLocation copyWith({
    String? city,
    String? province,
    String? postalCode,
    double? radiusKm,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    return ShoppingLocation(
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      radiusKm: radiusKm ?? this.radiusKm,
      latitude: clearCoordinates ? null : latitude ?? this.latitude,
      longitude: clearCoordinates ? null : longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'radius_km': radiusKm,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory ShoppingLocation.fromMap(Map<String, dynamic> map) {
    return ShoppingLocation(
      city: map['city']?.toString() ?? '',
      province: map['province']?.toString() ?? '',
      postalCode: map['postal_code']?.toString() ?? '',
      radiusKm: _toDouble(map['radius_km']) ?? 25,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
    );
  }

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

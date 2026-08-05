class Store {
  final String id;
  final String name;
  final String chainName;
  final String storeName;
  final String address;
  final String city;
  final String province;
  final String postalCode;
  final String phone;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final DateTime? createdAt;

  const Store({
    required this.id,
    required this.name,
    required this.chainName,
    required this.storeName,
    required this.address,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.createdAt,
  });

  factory Store.fromMap(Map<String, dynamic> map) {
    final legacyName = (map['name'] ?? '').toString().trim();
    final chainName = (map['chain_name'] ?? legacyName).toString().trim();
    final storeName = (map['store_name'] ?? legacyName).toString().trim();

    return Store(
      id: (map['id'] ?? '').toString(),
      name: legacyName.isNotEmpty
          ? legacyName
          : storeName.isNotEmpty
          ? storeName
          : chainName,
      chainName: chainName,
      storeName: storeName,
      address: (map['address'] ?? '').toString().trim(),
      city: (map['city'] ?? '').toString().trim(),
      province: (map['province'] ?? '').toString().trim(),
      postalCode: (map['postal_code'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      isActive: map['is_active'] as bool? ?? true,
      createdAt: _toDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.trim().isNotEmpty) 'id': id.trim(),
      'name': name.trim(),
      'chain_name': chainName.trim(),
      'store_name': storeName.trim(),
      'address': address.trim().isEmpty ? null : address.trim(),
      'city': city.trim(),
      'province': province.trim(),
      'postal_code': postalCode.trim().isEmpty ? null : postalCode.trim(),
      'phone': phone.trim().isEmpty ? null : phone.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    };
  }

  Store copyWith({
    String? id,
    String? name,
    String? chainName,
    String? storeName,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    String? phone,
    double? latitude,
    double? longitude,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      chainName: chainName ?? this.chainName,
      storeName: storeName ?? this.storeName,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      phone: phone ?? this.phone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }

  String get displayName {
    if (storeName.isNotEmpty) return storeName;
    if (name.isNotEmpty) return name;
    return chainName;
  }

  String get locationLabel {
    final locationParts = [
      if (address.isNotEmpty) address,
      if (city.isNotEmpty) city,
      if (province.isNotEmpty) province,
      if (postalCode.isNotEmpty) postalCode,
    ];

    return locationParts.join(', ');
  }

  @override
  String toString() {
    final location = locationLabel;

    if (location.isEmpty) {
      return displayName;
    }

    return '$displayName ($location)';
  }
}

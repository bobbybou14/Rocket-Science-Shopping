class Store {
  final String id;
  final String name;
  final String province;
  final String city;

  const Store({
    required this.id,
    required this.name,
    required this.province,
    required this.city,
  });

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      province: map['province'] ?? '',
      city: map['city'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'province': province, 'city': city};
  }

  @override
  String toString() => '$name ($city, $province)';
}

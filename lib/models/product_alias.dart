class ProductAlias {
  final String id;
  final String alias;
  final String normalizedAlias;
  final String productBarcode;
  final String productName;
  final int timesUsed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductAlias({
    required this.id,
    required this.alias,
    required this.normalizedAlias,
    required this.productBarcode,
    required this.productName,
    this.timesUsed = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductAlias.fromMap(Map<String, dynamic> map) {
    return ProductAlias(
      id: map['id']?.toString() ?? '',
      alias: map['alias']?.toString() ?? '',
      normalizedAlias: map['normalized_alias']?.toString() ?? '',
      productBarcode: map['product_barcode']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      timesUsed: _toInt(map['times_used']),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alias': alias,
      'normalized_alias': normalizedAlias,
      'product_barcode': productBarcode,
      'product_name': productName,
      'times_used': timesUsed,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ProductAlias copyWith({
    String? id,
    String? alias,
    String? normalizedAlias,
    String? productBarcode,
    String? productName,
    int? timesUsed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductAlias(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      normalizedAlias: normalizedAlias ?? this.normalizedAlias,
      productBarcode: productBarcode ?? this.productBarcode,
      productName: productName ?? this.productName,
      timesUsed: timesUsed ?? this.timesUsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 1;
  }
}

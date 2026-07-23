class Product {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String size;
  final String imageUrl;
  final bool taxable;

  const Product({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.category = '',
    this.size = '',
    this.imageUrl = '',
    this.taxable = false,
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
    };
  }
}

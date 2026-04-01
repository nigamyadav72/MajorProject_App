class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final List<String> categories;
  final double rating;
  final int ratingCount;
  final String stockStatus;
  final String sku;
  final int stock;
  final int salesCount;
  final double earnings;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categories,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.stockStatus = 'in_stock',
    this.sku = '',
    this.stock = 0,
    this.salesCount = 0,
    this.earnings = 0.0,
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? json['short_description'] ?? '',
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      imageUrl: _parseImageUrl(json),
      categories: [json['category_name']?.toString() ?? ''],
      rating: (json['rating_average'] is num)
          ? (json['rating_average'] as num).toDouble()
          : double.tryParse(json['rating_average']?.toString() ?? '0') ?? 0,
      ratingCount: (json['rating_count'] is int)
          ? json['rating_count'] as int
          : int.tryParse(json['rating_count']?.toString() ?? '0') ?? 0,
      stockStatus: json['stock_status'] ?? 'in_stock',
      sku: json['sku']?.toString() ?? '',
      stock: (json['stock'] is int) ? json['stock'] : (int.tryParse(json['stock']?.toString() ?? '0') ?? 0),
      salesCount: (json['sales_count'] is int) ? json['sales_count'] : (int.tryParse(json['sales_count']?.toString() ?? '0') ?? 0),
      earnings: (json['earnings'] is num)
          ? (json['earnings'] as num).toDouble()
          : double.tryParse(json['earnings']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  static String _parseImageUrl(Map<String, dynamic> json) {
    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty && json['image_url'].toString() != 'null') {
      return json['image_url'].toString();
    }
    if (json['primary_image'] != null && json['primary_image']['image'] != null && json['primary_image']['image'].toString().isNotEmpty) {
      return json['primary_image']['image'].toString();
    }
    if (json['image'] != null && json['image'].toString().isNotEmpty && json['image'].toString() != 'null') {
      return json['image'].toString();
    }
    return '';
  }
}

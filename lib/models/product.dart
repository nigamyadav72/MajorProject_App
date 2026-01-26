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
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'],
      description: json['description'] ?? json['short_description'] ?? '',
      price: double.parse(json['price']),
      imageUrl: json['image'],
      categories: [json['category_name']],
      rating: double.parse(json['rating_average'] ?? '0'),
      ratingCount: json['rating_count'] ?? 0,
      stockStatus: json['stock_status'] ?? 'in_stock',
    );
  }
}

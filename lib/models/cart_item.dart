class CartItem {
  final String id;
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
  });

  double get lineTotal => price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Backend CartItemSerializer usually has nested product or product_details
    final product = json['product_details'] ?? json['product'];
    
    // Attempt to extract name from various possible keys
    String name = 'Product';
    if (product is Map) {
      name = product['name'] ?? product['product_name'] ?? product['item_name'] ?? 'Product';
    } else if (json['product_name'] != null) {
      name = json['product_name'];
    } else if (json['product_details_name'] != null) {
      name = json['product_details_name'];
    }

    // Attempt to extract price from various possible keys
    double price = 0.0;
    if (product is Map && product['price'] != null) {
      price = double.parse(product['price'].toString());
    } else if (json['price'] != null) {
      price = double.parse(json['price'].toString());
    } else if (json['product_price'] != null) {
      price = double.parse(json['product_price'].toString());
    }

    // Attempt to extract image from various possible keys
    String? imageUrl;
    if (product is Map) {
      imageUrl = product['image'] ?? 
                 product['image_url'] ?? 
                 product['imageUrl'] ?? 
                 product['thumbnail'] ?? 
                 product['photo'] ?? 
                 product['picture'] ?? 
                 product['product_image'];
    }
    
    // Fallback to root level if still null
    imageUrl ??= json['image'] ?? 
                 json['image_url'] ?? 
                 json['product_image'] ?? 
                 json['thumbnail'] ?? 
                 json['photo'];

    return CartItem(
      id: json['id'].toString(),
      productId: (product is Map) ? product['id'].toString() : json['product'].toString(),
      name: name,
      price: price,
      quantity: json['quantity'] ?? 1,
      imageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'product': productId,
        'quantity': quantity,
      };
}

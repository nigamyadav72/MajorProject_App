class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
  });

  double get lineTotal => price * quantity;
}

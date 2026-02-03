import 'product.dart';

class OrderItem {
  final int id;
  final Product product;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      product: Product.fromJson(json['product']),
      quantity: json['quantity'],
      price: double.parse(json['price'].toString()),
    );
  }
}

class Order {
  final int id;
  final String status;
  final double totalPrice;
  final String shippingAddress;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? transactionId;

  Order({
    required this.id,
    required this.status,
    required this.totalPrice,
    required this.shippingAddress,
    required this.createdAt,
    required this.items,
    this.transactionId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<OrderItem> orderItems = itemsList.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: json['id'],
      status: json['status'],
      totalPrice: double.parse(json['total_price'].toString()),
      shippingAddress: json['shipping_address'] ?? 'No address provided',
      createdAt: DateTime.parse(json['created_at']),
      items: orderItems,
      transactionId: json['transaction_id'],
    );
  }
}

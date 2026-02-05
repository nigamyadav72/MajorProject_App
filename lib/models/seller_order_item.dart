import 'product.dart';

class SellerOrderItem {
  final int id;
  final Product product;
  final int quantity;
  final double price;
  final String orderStatus;
  final DateTime orderDate;
  final String customerEmail;

  SellerOrderItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.price,
    required this.orderStatus,
    required this.orderDate,
    required this.customerEmail,
  });

  factory SellerOrderItem.fromJson(Map<String, dynamic> json) {
    return SellerOrderItem(
      id: json['id'],
      product: Product.fromJson(json['product']),
      quantity: json['quantity'],
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : double.parse(json['price'].toString()),
      orderStatus: json['order_status'] ?? 'pending',
      orderDate: DateTime.parse(json['order_date']),
      customerEmail: json['customer_email'] ?? '',
    );
  }
}

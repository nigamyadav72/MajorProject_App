import 'package:flutter/material.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  void addToCart(CartItem item) {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _items[idx] = CartItem(
        id: _items[idx].id,
        name: _items[idx].name,
        price: _items[idx].price,
        quantity: _items[idx].quantity + item.quantity,
        imageUrl: _items[idx].imageUrl ?? item.imageUrl,
      );
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeFromCart(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      removeFromCart(id);
      return;
    }
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final it = _items[idx];
    _items[idx] = CartItem(
      id: it.id,
      name: it.name,
      price: it.price,
      quantity: quantity,
      imageUrl: it.imageUrl,
    );
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

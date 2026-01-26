import 'package:flutter/material.dart';
import '../models/product.dart';

class WishlistProvider extends ChangeNotifier {
  final List<Product> _items = [];

  List<Product> get items => _items;

  bool isInWishlist(String id) => _items.any((item) => item.id == id);

  void addToWishlist(Product product) {
    if (!isInWishlist(product.id)) {
      _items.add(product);
      notifyListeners();
    }
  }

  void removeFromWishlist(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}

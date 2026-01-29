import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class WishlistProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Product> _items = [];
  bool _isLoading = false;

  List<Product> get items => _items;
  bool get isLoading => _isLoading;

  bool isInWishlist(String id) => _items.any((item) => item.id == id);

  Future<void> fetchWishlist() async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> data = await _apiService.fetchWishlist();
      _items = data.map((json) => Product.fromJson(json['product_details'] ?? json['product'])).toList();
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToWishlist(Product product) async {
    if (!isInWishlist(product.id)) {
      try {
        await _apiService.addToWishlist(int.parse(product.id));
        await fetchWishlist(); // Refresh from backend
      } catch (e) {
        debugPrint('Error adding to wishlist: $e');
      }
    }
  }

  Future<void> removeFromWishlist(String productId) async {
    try {
      await _apiService.removeFromWishlist(int.parse(productId));
      await fetchWishlist();
    } catch (e) {
      debugPrint('Error removing from wishlist: $e');
    }
  }
}

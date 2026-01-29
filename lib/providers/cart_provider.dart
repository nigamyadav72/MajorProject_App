import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<CartItem> _items = [];
  bool _isLoading = false;

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  Future<void> fetchCart() async {
    _isLoading = true;
    notifyListeners();
    try {
      final dynamic response = await _apiService.fetchCart();
      List<dynamic> data = [];
      
      if (response is List) {
        data = response;
      } else if (response is Map && response['items'] != null) {
        data = response['items'] as List;
      }

      _items = data.map((json) => CartItem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToCart(int productId, {int quantity = 1}) async {
    try {
      await _apiService.addToCart(productId, quantity);
      await fetchCart(); // Refresh local state from backend
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  Future<void> removeFromCart(String id) async {
    debugPrint('🗑️ CartProvider: Removing item ID: $id');
    
    // Save old list for rollback
    final oldItems = List<CartItem>.from(_items);
    
    // Optimistic UI Update
    _items.removeWhere((item) => item.id == id);
    notifyListeners();

    try {
      final numericId = int.tryParse(id);
      if (numericId == null) {
        throw Exception('Invalid Item ID format: $id (must be an integer)');
      }
      await _apiService.removeCartItem(numericId);
      // Optionally fetchCart() here to ensure sync, but optimistic is done
    } catch (e) {
      debugPrint('❌ Error removing from cart: $e');
      _items = oldItems; // Rollback
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateQuantity(String id, int quantity) async {
    debugPrint('🔄 CartProvider: Updating item ID: $id to quantity: $quantity');
    
    if (quantity <= 0) {
      await removeFromCart(id);
      return;
    }

    // Save old list for rollback
    final oldItems = List<CartItem>.from(_items);

    // Optimistic UI Update
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final oldItem = _items[index];
      _items[index] = CartItem(
        id: oldItem.id,
        productId: oldItem.productId,
        name: oldItem.name,
        price: oldItem.price,
        quantity: quantity,
        imageUrl: oldItem.imageUrl,
      );
      notifyListeners();
    }

    try {
      final numericId = int.tryParse(id);
      if (numericId == null) {
        throw Exception('Invalid Item ID format: $id (must be an integer)');
      }
      await _apiService.updateCartItem(numericId, quantity);
      // Data updated on server, local state is already correct
    } catch (e) {
      debugPrint('❌ Error updating quantity: $e');
      _items = oldItems; // Rollback
      notifyListeners();
      // await fetchCart(); // Alternative rollback
    }
  }

  Future<void> clearCart() async {
    try {
      await _apiService.clearCart();
      _items.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cart: $e');
    }
  }
}

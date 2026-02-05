import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class SellerProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _myProducts = [];
  Map<String, dynamic> _stats = {
    'totalProducts': 0,
    'liveProducts': 0,
    'lowStock': 0,
    'totalEarnings': 0.0,
    'totalSales': 0,
  };
  bool _isLoading = false;
  String? _error;

  List<Product> get myProducts => _myProducts;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.fetchSellerProducts(),
        _apiService.fetchSellerStats(),
      ]);

      _myProducts = results[0] as List<Product>;
      _stats = results[1] as Map<String, dynamic>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(int productId) async {
    try {
      await _apiService.deleteProduct(productId);
      _myProducts.removeWhere((p) => p.id == productId.toString());
      notifyListeners();
      await fetchDashboardData(); // Refresh stats
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addProduct({
    required String name,
    required String description,
    required String shortDescription,
    required double price,
    required int categoryId,
    required int stock,
    required String sku,
    required bool isActive,
    File? imageFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _apiService.addProduct(
        name: name,
        description: description,
        shortDescription: shortDescription,
        price: price,
        categoryId: categoryId,
        stock: stock,
        sku: sku,
        isActive: isActive,
        imageFile: imageFile,
      );
      await fetchDashboardData();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

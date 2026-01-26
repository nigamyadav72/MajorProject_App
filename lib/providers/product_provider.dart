import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  List<String> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _products = await _apiService.fetchProducts();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await _apiService.fetchCategories();
      _categories.insert(0, 'All');
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  List<Product> getFilteredProducts(String category, String searchQuery) {
    List<Product> filtered = _products;
    if (category != 'All') {
      filtered =
          filtered.where((p) => p.categories.contains(category)).toList();
    }
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
              (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    return filtered;
  }
}

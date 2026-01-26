import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // -------------------- DATA --------------------
  List<Product> _products = [];
  List<Category> _categories = []; // now a list of Category objects
  Category? _selectedCategory; // currently selected category

  bool _isLoading = false;
  String? _error;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;

  // Search
  String _searchQuery = '';

  // Getter for incremental search
  List<Product> get filteredProducts {
    if (_searchQuery.isEmpty) return _products;

    final query = _searchQuery.toLowerCase();

    final startsWith =
        _products.where((p) => p.name.toLowerCase().startsWith(query)).toList();
    final contains = _products
        .where((p) =>
            p.name.toLowerCase().contains(query) &&
            !p.name.toLowerCase().startsWith(query))
        .toList();

    return [...startsWith, ...contains];
  }

  // Set search query for local filtering
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // -------------------- GETTERS --------------------
  List<Product> get products => _products;
  List<Category> get categories => _categories;
  Category? get selectedCategory => _selectedCategory;

  bool get isLoading => _isLoading;
  String? get error => _error;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasNext => _hasNext;
  bool get hasPrevious => _hasPrevious;

  String get searchQuery => _searchQuery;

  // -------------------- FETCH PRODUCTS --------------------
  Future<void> fetchProducts({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    _isLoading = true;
    _error = null;

    if (search != null) _searchQuery = search;

    notifyListeners();

    try {
      final result = await _apiService.fetchProducts(
        page: page,
        limit: limit,
        categoryId:
            (_selectedCategory == null || _selectedCategory!.name == 'All')
                ? null
                : _selectedCategory!.id,
        search: _searchQuery,
      );

      _products = result['products'];
      _currentPage = result['current_page'];
      _totalPages = result['total_pages'];
      _hasNext = result['has_next'];
      _hasPrevious = result['has_previous'];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -------------------- PAGINATION HELPERS --------------------
  void nextPage() {
    if (_hasNext) {
      fetchProducts(page: _currentPage + 1);
    }
  }

  void previousPage() {
    if (_hasPrevious) {
      fetchProducts(page: _currentPage - 1);
    }
  }

  // -------------------- FILTER HELPERS --------------------
  void changeCategory(Category? category) {
    _selectedCategory = category;
    fetchProducts(page: 1);
  }

  void changeSearch(String search) {
    _searchQuery = search;
    fetchProducts(page: 1);
  }

  // -------------------- FETCH CATEGORIES --------------------
  Future<void> fetchCategories() async {
    try {
      final data =
          await _apiService.fetchCategories(); // returns List<Category>
      _categories = [Category(id: 0, name: 'All'), ...data]; // add "All"
      _selectedCategory = _categories.first; // default = All
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }
}

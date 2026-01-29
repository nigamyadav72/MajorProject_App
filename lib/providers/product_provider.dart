```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

class VisualSearchResult {
  final Product product;
  final double confidence;

  VisualSearchResult({required this.product, required this.confidence});
}

class VisualSearchResultsPage extends StatelessWidget {
  // The provided snippet seems to be incomplete or misplaced.
  // The line 'product;' is syntactically incorrect here.
  // Assuming the intent was to add a new class definition,
  // but the content within it is problematic.
  // For now, I will add the class definition as provided,
  // but note the syntax error.
  // If this was meant to be part of VisualSearchResult, it's a duplicate.
  // If it's meant to be part of VisualSearchResultsPage, it's incomplete.
  // Keeping the structure as close to the provided snippet as possible,
  // while acknowledging the syntax issue.
  // product; // This line is syntactically incorrect.
  // final double confidence; // This would be a duplicate if inside VisualSearchResult.
  // VisualSearchResult({required this.product, required this.confidence}); // This would be a duplicate if inside VisualSearchResult.

  // To make it syntactically correct, I'll make it an empty StatelessWidget.
  const VisualSearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visual Search Results')),
      body: const Center(child: Text('Visual Search Results Page')),
    );
  }
}

class ProductProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // -------------------- DATA --------------------
  List<Product> _products = [];
  List<Category> _categories = []; 
  Category? _selectedCategory; 

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

  // -------------------- VISUAL SEARCH --------------------
  List<VisualSearchResult> _visualSearchResults = [];
  List<VisualSearchResult> get visualSearchResults => _visualSearchResults;

  Future<void> visualSearch(File imageFile) async {
    _isLoading = true;
    _error = null;
    _visualSearchResults = [];
    notifyListeners();

    try {
      final List<Map<String, dynamic>> results = await _apiService.visualSearch(imageFile);
      
      if (results.isEmpty) {
        _visualSearchResults = [];
      } else {
        final result = await _apiService.fetchProducts(
          page: 1,
          limit: 100, // Fetch more to find matches
        );
        
        final allProducts = result['products'] as List<Product>;
        
        _visualSearchResults = results.map((res) {
          final targetId = res['id'].toString();
          final product = allProducts.firstWhere(
            (p) => p.id == targetId,
            orElse: () => Product(
              id: targetId,
              name: 'Unknown Product',
              description: '',
              price: 0,
              imageUrl: '',
              categories: [],
              stockStatus: 'out_of_stock',
              rating: 0,
              ratingCount: 0,
            ),
          );
          return VisualSearchResult(product: product, confidence: res['confidence']);
        }).toList();

        _visualSearchResults.removeWhere((e) => e.product.name == 'Unknown Product');
      }
    } catch (e) {
      _error = 'Visual Search Failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -------------------- FETCH CATEGORIES --------------------
  Future<void> fetchCategories() async {
    try {
      final data = await _apiService.fetchCategories(); 
      _categories = [Category(id: 0, name: 'All'), ...data]; 
      _selectedCategory = _categories.first; 
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }
}

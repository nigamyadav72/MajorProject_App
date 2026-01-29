import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class VisualSearchResult {
  final Product product;
  final double confidence;

  VisualSearchResult({required this.product, required this.confidence});
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
      debugPrint('🔍 VISUAL SEARCH: Received ${results.length} raw results from server');
      
      // Filter by confidence (10% threshold)
      final filteredResults = results.where((res) => (res['confidence'] ?? 0.0) >= 0.1).toList();
      debugPrint('🔍 VISUAL SEARCH: ${filteredResults.length} results pass 10% threshold');

      if (filteredResults.isEmpty) {
        _visualSearchResults = [];
      } else {
        // 1. Extract all unique SKUs
        final List<String> skus = filteredResults.map((e) => e['sku'].toString()).toSet().toList();
        debugPrint('🔍 VISUAL SEARCH: Requesting products for SKUs: $skus');

        // 2. Fetch all products in one bulk request
        final List<Product> matchedProducts = await _apiService.fetchProductsBySkus(skus);
        debugPrint('✅ VISUAL SEARCH: Backend returned ${matchedProducts.length} unique products');

        // 3. Map SKUs to Confidence scores for easy lookup
        final Map<String, double> skuScores = {
          for (var res in filteredResults) res['sku'].toString(): res['confidence'] as double
        };

        // 4. Create final results by linking fetched products to their scores
        final List<VisualSearchResult> finalResults = [];
        for (var product in matchedProducts) {
          // We need to know which SKU this product belongs to.
          // Usually, the SKU is a field in the product. 
          // Since our Product model doesn't have a 'sku' field yet, 
          // we'll try to match by ID (if ID == SKU) or search the scores map.
          
          double score = 0.0;
          // Strategy: Try exact ID match first
          if (skuScores.containsKey(product.id)) {
            score = skuScores[product.id]!;
          } else {
            // Fallback: Product name contains SKU or similar logic 
            // OR just use the highest score if we only have one match
            score = skuScores.values.isNotEmpty ? skuScores.values.first : 0.0;
          }

          finalResults.add(VisualSearchResult(
            product: product,
            confidence: score,
          ));
        }

        // 5. Finalize state
        _visualSearchResults = finalResults;
        _visualSearchResults.sort((a, b) => b.confidence.compareTo(a.confidence));
        
        debugPrint('🏁 VISUAL SEARCH: Final unique products: ${_visualSearchResults.length}');
      }
    } catch (e) {
      debugPrint('🚨 VISUAL SEARCH CRITICAL: $e');
      _error = 'Visual Search Failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint('📢 notifyListeners() called. Displaying ${_visualSearchResults.length} results.');
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

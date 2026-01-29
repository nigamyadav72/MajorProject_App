import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/product_detail.dart';
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
      debugPrint('🔍 VISUAL SEARCH RAW RESULTS FROM SERVER: $results');
      
      // Temporary: low threshold (10%) to see if ANYTHING comes through
      final filteredResults = results.where((res) => (res['confidence'] ?? 0.0) >= 0.1).toList();
      debugPrint('🔍 Results above 10% threshold: ${filteredResults.length}');

      if (filteredResults.isEmpty) {
        debugPrint('⚠️ NO RESULTS PASS THE 10% THRESHOLD');
        _visualSearchResults = [];
      } else {
        debugPrint('🔍 Searching for Products matching SKUs: ${filteredResults.map((e) => e['sku']).toList()}');
        
        final List<Future<VisualSearchResult?>> detailFutures = filteredResults.map((res) async {
          try {
            final String sku = res['sku'];
            
            // 1. Try fetching by ID first (in case SKU == ID)
            ProductDetail? productDetail;
            if (int.tryParse(sku) != null) {
              productDetail = await _apiService.fetchProductDetail(int.parse(sku));
            }

            // 2. If not found, search for product by SKU string
            if (productDetail == null) {
              debugPrint('🔍 SKU $sku not found by ID, searching via name/sku search...');
              final searchResult = await _apiService.fetchProducts(page: 1, limit: 1, search: sku);
              final List<Product> searchProducts = searchResult['products'];
              
              if (searchProducts.isNotEmpty) {
                // Fetch the detail of the first match
                productDetail = await _apiService.fetchProductDetail(int.parse(searchProducts.first.id));
              }
            }

            if (productDetail != null) {
              debugPrint('✅ MATCH FOUND: ${productDetail.product.name} (SKU: $sku)');
              return VisualSearchResult(
                product: productDetail.product,
                confidence: res['confidence'] ?? 0.0,
              );
            } else {
              debugPrint('❌ NO DB MATCH: Could not find product with SKU $sku');
            }
          } catch (e) {
            debugPrint('⚠️ Error matching SKU ${res['sku']}: $e');
          }
          return null;
        }).toList();

        final List<VisualSearchResult?> fetchedResults = await Future.wait(detailFutures);
        final List<VisualSearchResult> allMatches = fetchedResults.whereType<VisualSearchResult>().toList();

        // Deduplicate by Product ID (keep highest confidence)
        final Map<String, VisualSearchResult> uniqueResults = {};
        for (var match in allMatches) {
          final id = match.product.id;
          if (!uniqueResults.containsKey(id) || match.confidence > uniqueResults[id]!.confidence) {
            uniqueResults[id] = match;
          }
        }

        _visualSearchResults = uniqueResults.values.toList();
        
        // Sort by confidence descending
        _visualSearchResults.sort((a, b) => b.confidence.compareTo(a.confidence));
        
        debugPrint('🏁 FINAL DEDUPLICATED RESULTS DISPLAYED: ${_visualSearchResults.length}');
      }
    } catch (e) {
      debugPrint('🚨 PROVIDER CRITICAL ERROR: $e');
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

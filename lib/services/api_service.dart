import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/category.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.10.67:8000/api';
  static const Duration timeoutDuration = Duration(seconds: 60);

  final http.Client _client = http.Client();

  // ============================
  // ✅ FETCH PRODUCTS (PAGINATED)
  // ============================
  Future<Map<String, dynamic>> fetchProducts({
    int page = 1,
    int limit = 10,
    int? categoryId, // 🔥 ID only
    String search = '',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/products/').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (categoryId != null) 'category': categoryId.toString(),
          if (search.isNotEmpty) 'search': search,
        },
      );

      final response = await _client.get(uri).timeout(timeoutDuration);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load products (${response.statusCode})',
        );
      }

      final decoded = json.decode(response.body);

      final List<Product> products =
          (decoded['results'] as List).map((e) => Product.fromJson(e)).toList();

      return {
        'products': products,
        'current_page': decoded['current_page'] ?? page,
        'total_pages':
            decoded['total_pages'] ?? (decoded['count'] / limit).ceil(),
        'has_next': decoded['next'] != null,
        'has_previous': decoded['previous'] != null,
      };
    } on TimeoutException {
      throw Exception('Request timeout. Please try again.');
    } catch (e) {
      throw Exception('Error fetching products: $e');
    }
  }

  // ============================
  // ✅ FETCH CATEGORIES (ID + NAME)
  // ============================
  Future<List<Category>> fetchCategories() async {
    try {
      final uri = Uri.parse('$baseUrl/categories/');

      final response = await _client.get(uri).timeout(timeoutDuration);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load categories (${response.statusCode})',
        );
      }

      final List<dynamic> decoded = json.decode(response.body);

      return decoded.map((e) => Category.fromJson(e)).toList();
    } on TimeoutException {
      throw Exception('Request timeout. Please try again.');
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  // ============================
  // ✅ CLEANUP
  // ============================
  void dispose() {
    _client.close();
  }
}

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/product.dart';
import '../models/product_detail.dart';
import '../models/category.dart';

class ApiService {
  static String get baseUrl => '${AppConfig.backendBaseUrl}/api';
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
  // ✅ FETCH PRODUCT BY ID (DETAIL)
  // ============================
  Future<ProductDetail?> fetchProductById(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/products/$id/');
      final response = await _client.get(uri).timeout(timeoutDuration);
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return ProductDetail.fromJson(decoded);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
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
  // ✅ KHALTI PAYMENT INITIATION
  // ============================
  Future<Map<String, dynamic>> initiateKhaltiPayment({
    required String name,
    required double amount, // in Rupees
    required String email,
    required String phone,
    required String productId,
    required String productName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/payment/khalti/initiate/');
      
      // Amount in backend expects Paisa (usually) or the backend code converts it. 
      // Looking at the user's Node code: `amount: body.amount`.
      // Looking at the user's Python code: `amount: data.get('amount')`.
      // The Khalti API expects Paisa.
      // IF the backend expects Rupees, we shouldn't multiply. 
      // IF the backend forwards raw amount, we MUST send Paisa.
      // Safety: Send Paisa from here if backend is just a proxy.
      // However, usually better to send Rupees and let backend handle, OR adhere to Khalti Standard (Paisa).
      // Let's assume we send Paisa (amount * 100).
      
      final payload = {
        "name": name,
        "amount": (amount * 100).toInt(), // Convert to Paisa
        "email": email,
        "phone": phone,
        "product_identity": productId,
        "product_name": productName,
        "website_url": "https://example.com", // Or app specific
        // return_url is handled by backend or default
      };

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to initiate payment (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = json.decode(response.body);
      return decoded; // Should contain 'pidx', 'payment_url', etc.
    } on TimeoutException {
      throw Exception('Request timeout. Please try again.');
    } catch (e) {
      throw Exception('Error initiating payment: $e');
    }
  }

  // ============================
  // ✅ PASSWORD RESET
  // ============================
  Future<void> requestPasswordReset(String email) async {
    try {
      const url = '${AppConfig.backendBaseUrl}/api/auth/password/reset/';
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ Password reset success on: $url');
        return; // Success
      }
      
      final body = json.decode(response.body);
      final errorMsg = body['detail'] ?? body['error'] ?? 'Status ${response.statusCode}';
      throw Exception(errorMsg);
    } catch (e) {
      debugPrint('❌ Failed password reset: $e');
      rethrow;
    }
  }

  // ============================
  // ✅ CLEANUP
  // ============================
  void dispose() {
    _client.close();
  }
}

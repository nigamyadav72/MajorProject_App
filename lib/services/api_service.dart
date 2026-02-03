import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../models/product_detail.dart';
import '../models/category.dart';
import '../models/order.dart';

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
      final isSearch = search.isNotEmpty;
      final endpoint = isSearch ? '$baseUrl/products/search/' : '$baseUrl/products/';
      
      final uri = Uri.parse(endpoint).replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (!isSearch && categoryId != null) 'category': categoryId.toString(),
          if (isSearch) 'q': search,
          if (!isSearch && search.isNotEmpty) 'search': search, // Fallback for safety
        },
      );
      debugPrint('🌐 Fetching Products from: $uri');

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
  // ✅ FETCH PRODUCTS BY SKUS (BULK)
  // ============================
  Future<List<Product>> fetchProductsBySkus(List<String> skus) async {
    try {
      final uri = Uri.parse('$baseUrl/products/by-skus/');
      debugPrint('🚀 Fetch Products by SKUs: $uri with ${skus.length} SKUs');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'skus': skus}),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Bulk SKU search failed: ${response.statusCode}');
        return [];
      }

      final List<dynamic> decoded = json.decode(response.body);
      return decoded.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ Error in bulk SKU search: $e');
      return [];
    }
  }

  // ============================
  // ✅ FETCH PRODUCT BY ID (DETAIL)
  // ============================
  Future<ProductDetail?> fetchProductDetail(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/products/$id/');
      debugPrint('🚀 Fetch Product Detail: $uri');
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
      debugPrint('🚀 Fetch Categories: $uri');

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
    String? returnUrl,
    String? websiteUrl,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/payment/khalti/initiate/');
      debugPrint('🚀 Initiate Khalti Payment: $uri');
      
      final payload = {
        "name": name,
        "amount": (amount * 100).toInt(), // Convert to Paisa
        "email": email,
        "phone": phone,
        "product_identity": productId,
        "product_name": productName,
        // Mobile SDK doesn't redirect, but backend will use these for web clients
        "return_url": returnUrl ?? "${AppConfig.backendBaseUrl}/api/payment/success/",
        "website_url": websiteUrl ?? AppConfig.backendBaseUrl,
      };
      
      debugPrint('📡 Payment payload: $payload');

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
      debugPrint('🚀 Request Password Reset: $url');
      
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
  // ✅ AUTH HEADERS
  // ============================
  Future<Map<String, String>> _getAuthHeaders() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access');
    
    if (token == null) {
      debugPrint('⚠️ _getAuthHeaders: Token is NULL');
    } else {
      debugPrint('🔑 _getAuthHeaders: Token found (length: ${token.length})');
      // debugPrint('🔑 Token: $token'); // Uncomment to inspect full token if needed
    }

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================
  // ✅ CART API
  // ============================
  // ============================
  // ✅ VISUAL SEARCH (AI MODEL)
  // ============================
  Future<List<Map<String, dynamic>>> visualSearch(File imageFile) async {
    try {
      final uri = Uri.parse('${AppConfig.modelServerUrl}/search-image/');
      debugPrint('🚀 Visual Search (AI Model): $uri');

      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Updated from 'image' to 'file'
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Model server error (${response.statusCode}): ${response.body}');
      }

      final decoded = json.decode(response.body);
      
      // Handle response: {"results": [{"sku": "123", "similarity": 0.98}, ...]}
      final List<dynamic> resultsRaw = decoded['results'] ?? [];
      
      return resultsRaw.map((e) {
        return {
          'sku': e['sku']?.toString() ?? '', // Return the raw SKU string
          'confidence': double.parse((e['similarity'] ?? 0.0).toString()),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Visual Search Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchCart() async {
    try {
      final uri = Uri.parse('$baseUrl/cart/');
      debugPrint('🚀 Fetch Cart: $uri');
      final response = await _client.get(
        uri,
        headers: await _getAuthHeaders(),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch cart: ${response.statusCode}');
      }
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching cart: $e');
      rethrow;
    }
  }

  Future<void> addToCart(int productId, int quantity) async {
    try {
      final uri = Uri.parse('$baseUrl/cart/add/');
      debugPrint('🚀 Add to Cart POST: $uri');
      final response = await _client.post(
        uri,
        headers: await _getAuthHeaders(),
        body: json.encode({
          'product': productId,
          'quantity': quantity,
        }),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add to cart: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      rethrow;
    }
  }

  Future<void> updateCartItem(int itemId, int quantity) async {
    try {
      final url = '$baseUrl/cart/item/$itemId/update/';
      debugPrint('🚀 Update Cart Item PATCH: $url');
      final response = await _client.patch(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: json.encode({'quantity': quantity}),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200) {
        throw Exception('Failed to update cart item: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error updating cart: $e');
      rethrow;
    }
  }

  Future<void> removeCartItem(int itemId) async {
    try {
      final url = '$baseUrl/cart/item/$itemId/remove/';
      debugPrint('🚀 Remove Cart Item DELETE: $url');
      final response = await _client.delete(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to remove cart item: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error removing from cart: $e');
      rethrow;
    }
  }

  Future<void> clearCart() async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/cart/clear/'),
        headers: await _getAuthHeaders(),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to clear cart: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      rethrow;
    }
  }

  // ============================
  // ✅ WISHLIST API
  // ============================
  Future<List<dynamic>> fetchWishlist() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/wishlist/'),
        headers: await _getAuthHeaders(),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch wishlist');
      }
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
      rethrow;
    }
  }

  Future<void> addToWishlist(int productId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/wishlist/add/'),
        headers: await _getAuthHeaders(),
        body: json.encode({'product': productId}),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add to wishlist');
      }
    } catch (e) {
      debugPrint('Error adding to wishlist: $e');
      rethrow;
    }
  }

  Future<void> removeFromWishlist(int productId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/wishlist/remove/$productId/'),
        headers: await _getAuthHeaders(),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to remove from wishlist');
      }
    } catch (e) {
      debugPrint('Error removing from wishlist: $e');
      rethrow;
    }
  }

  // ============================
  // ✅ ORDERS API
  // ============================
  Future<List<Order>> fetchOrders() async {
    try {
      final uri = Uri.parse('$baseUrl/orders/');
      debugPrint('🚀 Fetch Orders: $uri');
      final response = await _client.get(
        uri,
        headers: await _getAuthHeaders(),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200) {
        debugPrint('❌ Fetch Orders Error: status=${response.statusCode}, body=${response.body}');
        throw Exception('Failed to fetch orders: ${response.statusCode}');
      }
      
      final List<dynamic> decoded = json.decode(response.body);
      return decoded.map((e) => Order.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required String shippingAddress,
    String? transactionId,
    String? buyNowProductId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/orders/');
      debugPrint('🚀 Create Order POST: $uri');
      final response = await _client.post(
        uri,
        headers: await _getAuthHeaders(),
        body: json.encode({
          'shipping_address': shippingAddress,
          if (transactionId != null) 'transaction_id': transactionId,
          if (buyNowProductId != null) 'buy_now_product_id': buyNowProductId,
          'status': 'ordered',
        }),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('❌ Create Order Error: ${response.body}');
        throw Exception('Failed to create order: ${response.body}');
      }
      
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  Future<void> cancelOrder(int orderId) async {
    try {
      final url = '$baseUrl/orders/$orderId/cancel/';
      debugPrint('🚀 Cancel Order POST: $url');
      final response = await _client.post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      ).timeout(timeoutDuration);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to cancel order: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
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

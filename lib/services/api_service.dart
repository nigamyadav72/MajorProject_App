// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your Django backend URL
  static const String baseUrl = 'http://your-django-backend.com/api';
  
  // Add your token if using authentication
  static String? authToken;

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  // Products
  static Future<List<dynamic>> getProducts({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/?page=$page'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results'] ?? data; // Adjust based on your API response
      }
      throw Exception('Failed to load products');
    } catch (e) {
      print('Error fetching products: $e');
      rethrow;
    }
  }

  // Search by text
  static Future<List<dynamic>> searchProducts(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/search/?q=${Uri.encodeComponent(query)}'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to search products');
    } catch (e) {
      print('Error searching products: $e');
      rethrow;
    }
  }

  // Visual search by image
  static Future<List<dynamic>> visualSearch(dynamic imageData, String filename) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/products/visual-search/'),
      );
      
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      
      // Handle both File and Uint8List
      if (imageData is File) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageData.path),
        );
      } else {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageData,
            filename: filename,
          ),
        );
      }
      
      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        return json.decode(responseData);
      }
      throw Exception('Failed to perform visual search');
    } catch (e) {
      print('Error in visual search: $e');
      rethrow;
    }
  }

  // Get product details
  static Future<Map<String, dynamic>> getProductDetail(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId/'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load product details');
    } catch (e) {
      print('Error fetching product details: $e');
      rethrow;
    }
  }

  // Categories
  static Future<List<dynamic>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load categories');
    } catch (e) {
      print('Error fetching categories: $e');
      rethrow;
    }
  }

  // Cart operations
  static Future<Map<String, dynamic>> getCart() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cart/'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load cart');
    } catch (e) {
      print('Error fetching cart: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addToCart(int productId, int quantity) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cart/add/'),
        headers: headers,
        body: json.encode({
          'product_id': productId,
          'quantity': quantity,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to add to cart');
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  static Future<void> removeFromCart(int cartItemId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/$cartItemId/'),
        headers: headers,
      );
      
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to remove from cart');
      }
    } catch (e) {
      print('Error removing from cart: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateCartItem(int cartItemId, int quantity) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/cart/$cartItemId/'),
        headers: headers,
        body: json.encode({'quantity': quantity}),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to update cart item');
    } catch (e) {
      print('Error updating cart item: $e');
      rethrow;
    }
  }

  // User authentication
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        authToken = data['token']; // Adjust based on your API
        return data;
      }
      throw Exception('Failed to login');
    } catch (e) {
      print('Error logging in: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to register');
    } catch (e) {
      print('Error registering: $e');
      rethrow;
    }
  }

  static void logout() {
    authToken = null;
  }

  // Orders
  static Future<List<dynamic>> getOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load orders');
    } catch (e) {
      print('Error fetching orders: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/create/'),
        headers: headers,
        body: json.encode(orderData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to create order');
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }
}
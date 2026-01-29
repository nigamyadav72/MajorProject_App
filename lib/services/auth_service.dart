import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConfig.googleWebClientId,
  );

  final _storage = const FlutterSecureStorage();

  /// Django Google login URL (same backend as web app).
  static String get _googleAuthUrl =>
      '${AppConfig.backendBaseUrl}/api/auth/google/';

  /// Sign in with Google, exchange ID token with Django, store JWT.
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return {'success': false, 'error': 'Sign in cancelled'};

      final GoogleSignInAuthentication auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Google ID token is null');
      }

      // Django CustomGoogleLogin expects "access_token" (used as id_token).
      final uri = Uri.parse(_googleAuthUrl);
      debugPrint('🚀 Google Auth POST: $uri');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': idToken}),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final msg = body['error'] ?? 'Google auth failed';
        throw Exception('$msg');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storage.write(key: 'access', value: data['access'] as String?);
      await _storage.write(key: 'refresh', value: data['refresh'] as String?);
      
      // Return user data from Google account if backend doesn't provide it
      return {
        'success': true,
        'user': data['user'] ?? {
          'name': account.displayName,
          'email': account.email,
          'picture': account.photoUrl,
        },
      };
    } catch (e) {
      debugPrint('Google Sign-In Exception: $e');
      String errorMessage = e.toString();
      if (e.toString().contains('ApiException: 10')) {
        errorMessage = 'Google Developer Error (10): Check SHA-1 and Client ID.';
      } else if (e.toString().contains('ApiException: 12500')) {
        errorMessage = 'Sign-in failed (12500): Check Google Play Services or configuration.';
      } else if (e.toString().contains('ApiException: 7')) {
        errorMessage = 'Network Error (7): Ensure your device has internet access.';
      }
      return {'success': false, 'error': errorMessage};
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access');
    return token != null;
  }

  /// Login with email and password
  Future<Map<String, dynamic>> loginWithEmail(String email, String password) async {
    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/auth/login/');
      debugPrint('🚀 Login POST: $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("❌ Login Error Body: ${response.body}"); // ADDED THIS
        final body = jsonDecode(response.body);
        String errorMsg = 'Login failed';
        
        if (body['non_field_errors'] != null) {
          errorMsg = (body['non_field_errors'] as List).first.toString();
        } else if (body['detail'] != null) {
          errorMsg = body['detail'];
        } else if (body['error'] != null) {
          errorMsg = body['error'];
        } else if (body['email'] != null) {
          errorMsg = "Email: ${(body['email'] as List).first}";
        } else if (body['password'] != null) {
          errorMsg = "Password: ${(body['password'] as List).first}";
        }
        
        throw Exception(errorMsg);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storage.write(key: 'access', value: data['access'] as String?);
      await _storage.write(key: 'refresh', value: data['refresh'] as String?);
      
      return {
        'success': true,
        'user': data['user'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Sign up with email and password
  Future<Map<String, dynamic>> signUpWithEmail({
    required String username,
    required String email,
    required String password,
    String? recaptchaToken,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/auth/register/');
      debugPrint('🚀 Register POST: $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'recaptcha_token': recaptchaToken ?? '', 
        }),
      );

      debugPrint('📥 Registration response status: ${response.statusCode}');
      debugPrint('📥 Registration response body: ${response.body}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        final body = jsonDecode(response.body);
        
        // Parse error messages
        String errorMsg = 'Registration failed';
        
        if (body['username'] != null) {
          errorMsg = 'Username: ${(body['username'] is List) ? body['username'][0] : body['username']}';
        } else if (body['email'] != null) {
          errorMsg = 'Email: ${(body['email'] is List) ? body['email'][0] : body['email']}';
        } else if (body['password'] != null) {
          errorMsg = 'Password: ${(body['password'] is List) ? body['password'][0] : body['password']}';
        } else if (body['error'] != null) {
          errorMsg = body['error'];
        } else if (body['detail'] != null) {
          errorMsg = body['detail'];
        }
        
        throw Exception(errorMsg);
      }

      return {'success': true};
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      return {
        'success': false,
        'error': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Get user profile from backend
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final token = await _storage.read(key: 'access');
      if (token == null) return null;

      const url = '${AppConfig.backendBaseUrl}/api/auth/profile/';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Test connection to backend
  Future<Map<String, dynamic>> testConnection() async {
    const url = '${AppConfig.backendBaseUrl}/api/categories/';
    try {
      debugPrint('🛠️ Testing connection to: $url');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      return {
        'success': response.statusCode == 200,
        'status': response.statusCode,
        'url': url,
        'message': 'Successfully reached server!',
      };
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return {
        'success': false,
        'url': url,
        'message': e.toString(),
      };
    }
  }
}

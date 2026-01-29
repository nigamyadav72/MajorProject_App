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
      final response = await http.post(
        Uri.parse(_googleAuthUrl),
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
      // ignore: avoid_print
      print('Google Sign-In Error: $e');
      return {'success': false, 'error': e.toString()};
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
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['detail'] ?? 'Login failed');
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
    required String email,
    required String password,
    required String name,
    String? recaptchaToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'username': email.split('@')[0], // Backend Serializer expects username
          'recaptcha_token': recaptchaToken ?? '', // Required by backend View
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? body['detail'] ?? body['email'] ?? 'Registration failed');
      }

      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
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
}

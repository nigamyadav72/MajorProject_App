import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final _storage = const FlutterSecureStorage();

  // 🔐 Google Sign-In
  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return false;

      final GoogleSignInAuthentication auth = await account.authentication;

      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception("Google ID token is null");
      }

      // 🔁 Send token to Django
      final response = await http.post(
        Uri.parse('http://YOUR_BACKEND_URL/api/auth/google/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await _storage.write(key: 'access', value: data['access']);
        await _storage.write(key: 'refresh', value: data['refresh']);

        return true;
      } else {
        throw Exception('Google auth failed');
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
      return false;
    }
  }

  // 🔓 Logout
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _storage.deleteAll();
  }

  // 🔎 Check auth
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access');
    return token != null;
  }
}

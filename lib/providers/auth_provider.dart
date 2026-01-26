import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isAuthenticated = false;
  bool _isLoading = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  // 🔎 Check token on app start
  Future<void> checkAuth() async {
    _isAuthenticated = await _authService.isLoggedIn();
    notifyListeners();
  }

  // 🔐 Google Login
  Future<void> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    final success = await _authService.signInWithGoogle();
    _isAuthenticated = success;

    _isLoading = false;
    notifyListeners();
  }

  // 🔓 Logout
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    notifyListeners();
  }
}

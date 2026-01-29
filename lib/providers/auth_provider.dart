import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isAuthenticated = false;
  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  bool _isSignupLoading = false;
  User? _user;

  bool get isAuthenticated => _isAuthenticated;
  bool get isGoogleLoading => _isGoogleLoading;
  bool get isEmailLoading => _isEmailLoading;
  bool get isSignupLoading => _isSignupLoading;
  bool get isLoading => _isGoogleLoading || _isEmailLoading || _isSignupLoading;
  User? get user => _user;

  // 🔎 Check token on app start and load user
  Future<void> checkAuth() async {
    _isAuthenticated = await _authService.isLoggedIn();
    if (_isAuthenticated) {
      await _loadUserProfile();
    }
    notifyListeners();
  }

  // 🔐 Google Login
  Future<void> loginWithGoogle() async {
    _isGoogleLoading = true;
    notifyListeners();

    final result = await _authService.signInWithGoogle();
    _isAuthenticated = result['success'] == true;
    
    if (_isAuthenticated) {
      if (result['user'] != null) {
        _user = User.fromJson(result['user']);
      }
      // Still attempt to sync with backend for latest data
      await _loadUserProfile();
    }

    _isGoogleLoading = false;
    notifyListeners();
  }

  // 🔓 Logout
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }

  // 📧 Email/Password Login
  Future<Map<String, dynamic>> loginWithEmail(String email, String password) async {
    _isEmailLoading = true;
    notifyListeners();

    final result = await _authService.loginWithEmail(email, password);
    if (result['success'] == true) {
      _isAuthenticated = true;
      // User data from email login
      if (result['user'] != null) {
        _user = User.fromJson(result['user']);
      } else {
        await _loadUserProfile();
      }
    }

    _isEmailLoading = false;
    notifyListeners();
    return result;
  }

  // ✍️ Email/Password Signup
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    _isSignupLoading = true;
    notifyListeners();

    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      name: name,
    );

    _isSignupLoading = false;
    notifyListeners();
    return result;
  }

  // 👤 Load user profile from backend
  Future<void> _loadUserProfile() async {
    final profile = await _authService.getUserProfile();
    if (profile != null) {
      _user = User.fromJson(profile);
      notifyListeners();
    }
  }
}

class User {
  final String name;
  final String email;
  final String? photoUrl;

  User({
    required this.name,
    required this.email,
    this.photoUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String name = '';
    
    // Try building from first/last name
    final fName = json['first_name']?.toString() ?? '';
    final lName = json['last_name']?.toString() ?? '';
    name = '$fName $lName'.trim();

    // Fallback to separate 'name' field if still empty
    if (name.isEmpty) {
      name = json['name']?.toString() ?? '';
    }

    // Ultimate fallback to username
    if (name.isEmpty) {
      name = json['username']?.toString() ?? 'User';
    }

    return User(
      name: name,
      email: json['email'] ?? '',
      photoUrl: json['picture'] ?? json['photo_url'],
    );
  }
}

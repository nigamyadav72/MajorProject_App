import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  bool _isSignupLoading = false;
  bool _needsOnboarding = false;
  User? _user;

  bool get needsOnboarding => _needsOnboarding;

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  bool get isGoogleLoading => _isGoogleLoading;
  bool get isEmailLoading => _isEmailLoading;
  bool get isSignupLoading => _isSignupLoading;
  bool get isLoading => _isGoogleLoading || _isEmailLoading || _isSignupLoading;
  User? get user => _user;

  // 🔎 Check token on app start and load user
  Future<void> checkAuth() async {
    _isInitialized = false;
    notifyListeners();

    try {
      final loggedIn = await _authService.isLoggedIn();
      if (loggedIn) {
        // Strictly verify by loading profile
        await _loadUserProfile();
        _isAuthenticated = _user != null;
      } else {
        _isAuthenticated = false;
        _user = null;
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
      _isAuthenticated = false;
      _user = null;
    } finally {
      final prefs = await SharedPreferences.getInstance();
      _needsOnboarding = !(prefs.getBool('onboarding_complete') ?? false);
      _isInitialized = true;
      notifyListeners();
    }
  }

  // 🔐 Google Login
  Future<Map<String, dynamic>> loginWithGoogle() async {
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
    return result;
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
    required String username,
    required String email,
    required String password,
    String? recaptchaToken,
    String role = 'buyer',
  }) async {
    _isSignupLoading = true;
    notifyListeners();

    final result = await _authService.signUpWithEmail(
      username: username,
      email: email,
      password: password,
      recaptchaToken: recaptchaToken,
      role: role,
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

  // 📝 Update user profile (Address/Phone)
  Future<Map<String, dynamic>> updateUserProfile({
    String? firstName,
    String? lastName,
    String? address,
    String? phone,
  }) async {
    final result = await _authService.updateUserProfile(
      firstName: firstName,
      lastName: lastName,
      address: address,
      phone: phone,
    );
    
    if (result['success'] == true && result['user'] != null) {
      _user = User.fromJson(result['user']);
      notifyListeners();
    }
    return result;
  }

  // 🛠️ Test Connection Diagnostic
  Future<Map<String, dynamic>> testConnection() async {
    return await _authService.testConnection();
  }

  void completeOnboarding() {
    _needsOnboarding = false;
    notifyListeners();
  }
}

class User {
  final int id;
  final String name;
  final String username;
  final String email;
  final String? photoUrl;
  final String address;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.photoUrl,
    this.address = '',
    this.phoneNumber = '',
    this.firstName = '',
    this.lastName = '',
    this.role = 'buyer',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String name = '';
    
    // Extracted directly or from profile
    final firstName = json['first_name']?.toString() ?? '';
    final lastName = json['last_name']?.toString() ?? '';
    name = '$firstName $lastName'.trim();

    // Fallback to separate 'name' field if still empty
    if (name.isEmpty) {
      name = json['name']?.toString() ?? '';
    }

    // Get username
    final username = json['username']?.toString() ?? '';

    // If name is still empty, use username as name
    if (name.isEmpty && username.isNotEmpty) {
      name = username;
    }

    // Final fallback
    if (name.isEmpty) {
      name = 'User';
    }

    debugPrint('📥 User.fromJson: parsing role from JSON: ${json['role']}');
    return User(
      id: json['id'] ?? 0,
      name: name,
      username: username,
      email: json['email'] ?? '',
      photoUrl: json['picture'] ?? json['photo_url'],
      address: json['address']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      firstName: firstName,
      lastName: lastName,
      role: json['role']?.toString() ?? 'buyer',
    );
  }
}

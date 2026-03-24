import 'package:flutter/material.dart';
import 'package:majorproject_app/login_screen.dart';
import 'package:majorproject_app/screens/onboarding_screen.dart';
import 'package:majorproject_app/screens/intro_splash_screen.dart';

import 'package:provider/provider.dart';

import 'bottom_nav.dart';
import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/product_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'providers/seller_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _splashFinished = false;

  void _onSplashFinished() {
    if (mounted) {
      setState(() => _splashFinished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (context) => CartProvider()..fetchCart()),
        ChangeNotifierProvider(create: (context) => WishlistProvider()..fetchWishlist()),
        ChangeNotifierProvider(create: (context) => ProductProvider()..fetchProducts()..fetchCategories()),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => OrderProvider()),
        ChangeNotifierProvider(create: (context) => SellerProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // If animations aren't done OR auth isn't initialized, show splash
          if (!_splashFinished || !auth.isInitialized) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: IntroSplashScreen(onComplete: _onSplashFinished),
            );
          }

          // Once BOTH are ready, show the main app
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'E-Pasal',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6366F1),
                primary: const Color(0xFF6366F1),
                secondary: const Color(0xFF06B6D4),
                surface: Colors.white,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              fontFamily: 'Outfit',
              textTheme: const TextTheme(
                headlineMedium: TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                bodyMedium: TextStyle(color: Color(0xFF475569)),
              ),
            ),
            home: auth.needsOnboarding
                ? const OnboardingScreen()
                : (auth.isAuthenticated ? const BottomNav() : const LoginPageThemeWrapper()),
          );
        },
      ),
    );
  }
}

// Simple wrapper to ensure LoginPage gets the right theme if needed
class LoginPageThemeWrapper extends StatelessWidget {
  const LoginPageThemeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginPage();
  }
}

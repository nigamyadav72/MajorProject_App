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
  bool _showSplash = true;

  void _onSplashComplete() {
    if (mounted) {
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If splash is still playing, show it as a standalone MaterialApp
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: IntroSplashScreen(onComplete: _onSplashComplete),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => SellerProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isInitialized) {
            // Simple loading while auth checks after splash
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: const Color(0xFF050505),
                body: Center(
                  child: CircularProgressIndicator(
                    color: const Color(0xFF6366F1),
                    strokeWidth: 3,
                  ),
                ),
              ),
            );
          }
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
                : (auth.isAuthenticated
                    ? const BottomNav()
                    : const LoginPage()),
          );
        },
      ),
    );
  }
}

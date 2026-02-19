import 'package:flutter/material.dart';
import 'package:majorproject_app/login_screen.dart';
import 'package:majorproject_app/screens/onboarding_screen.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: const Color(0xFF0F172A),
                body: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          size: 80,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'E-Pasal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const Text(
                        'AI Shopping Assistant',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(flex: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 4,
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF6366F1)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading application...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
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
                // background property is deprecated
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              fontFamily: 'Outfit', // A more modern font feel
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

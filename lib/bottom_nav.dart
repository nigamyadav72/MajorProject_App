import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majorproject_app/home_screen.dart';
import 'explore_page.dart';
import 'cart_page.dart';
import 'wishlist_page.dart';
import 'profile_page.dart';
import 'providers/navigation_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/product_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'screens/visual_search_results_page.dart';

class BottomNav extends StatefulWidget {
  final int initialIndex;
  
  const BottomNav({super.key, this.initialIndex = 0});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationProvider>().setIndex(widget.initialIndex);
      context.read<CartProvider>().fetchCart();
      context.read<WishlistProvider>().fetchWishlist();
    });
  }

  final List<Widget> _pages = const [
    HomePage(),
    ExplorePage(),
    CartPage(),
    ProfilePage(),
    WishlistPage(), // Keep available but maybe not in bottom bar
  ];

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final currentIndex = navigationProvider.selectedIndex;


    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      floatingActionButton: Container(
        height: 65,
        width: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _handleVisualSearch,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.center_focus_strong_rounded,
                color: Colors.white,
                size: 32,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 15,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side items
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, "Home", navigationProvider),
                  _buildNavItem(1, Icons.explore_outlined, Icons.explore, "Market", navigationProvider),
                ],
              ),
              // Right side items
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(2, Icons.shopping_cart_outlined, Icons.shopping_cart, "Cart", navigationProvider),
                  _buildNavItem(3, Icons.person_outline, Icons.person, "Profile", navigationProvider),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, NavigationProvider provider) {
    final isSelected = provider.selectedIndex == index;
    return MaterialButton(
      minWidth: 40,
      onPressed: () => provider.setIndex(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVisualSearch() async {
    final ImagePicker picker = ImagePicker();
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Visual Search",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF6366F1)),
              title: const Text("Take a Photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF6366F1)),
              title: const Text("Choose from Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                SizedBox(width: 20),
                Text("Analyzing image..."),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        await context.read<ProductProvider>().visualSearch(File(image.path));
        
        if (!mounted) return;
        
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VisualSearchResultsPage()),
        );
      }
    }
  }
}

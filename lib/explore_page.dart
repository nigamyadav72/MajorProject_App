import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import 'screens/visual_search_results_page.dart';


class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      provider.fetchCategories();
      provider.fetchProducts();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleVisualSearch() async {
    final ImagePicker picker = ImagePicker();

    // Show option for Camera or Gallery
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
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFF6B6B)),
              title: const Text("Take a Photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFFF6B6B)),
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

        // Show loading
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

        // Perform visual search
        await context.read<ProductProvider>().visualSearch(File(image.path));

        // Navigate to dedicated results page
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VisualSearchResultsPage()),
        );
      }
    }
  }

  void _loadPage(int page) {
    Provider.of<ProductProvider>(context, listen: false)
        .fetchProducts(page: page);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);

    // Sync search field with provider search (Home → Explore)
    if (_searchController.text != provider.searchQuery) {
      _searchController.text = provider.searchQuery;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(provider),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildCategoryChips(provider),
                const SizedBox(height: 10),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: provider.isLoading
                ? const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()))
                : provider.error != null
                    ? SliverToBoxAdapter(child: Center(child: Text(provider.error!)))
                    : provider.filteredProducts.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Center(child: Text('No products found')))
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return ProductCard(
                                  product: provider.filteredProducts[index],
                                );
                              },
                              childCount: provider.filteredProducts.length,
                            ),
                          ),
          ),
          if (!provider.isLoading && provider.totalPages > 1)
            SliverToBoxAdapter(
              child: _buildPagination(provider),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ProductProvider provider) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Explore",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const Text(
                    "Discover amazing products",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Spacer(),
                  _buildExploreSearchBar(provider),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExploreSearchBar(ProductProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue value) {
          if (value.text.isEmpty) return const Iterable<String>.empty();
          return provider.products
              .map((p) => p.name)
              .where((name) => name.toLowerCase().contains(value.text.toLowerCase()))
              .toList();
        },
        onSelected: (String selection) => provider.changeSearch(selection),
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          if (_searchController.text != controller.text && _searchController.text.isNotEmpty) {
             controller.text = _searchController.text;
          }
          return TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (value) {
              _searchController.text = value;
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                provider.setSearchQuery(value);
              });
            },
            onSubmitted: (value) => provider.changeSearch(value),
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B6B)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 20),
                onPressed: _handleVisualSearch,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips(ProductProvider provider) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: provider.categories.length,
        itemBuilder: (context, index) {
          final category = provider.categories[index];
          final selected = category == provider.selectedCategory;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ChoiceChip(
              label: Text(category.name),
              selected: selected,
              onSelected: (_) {
                provider.changeCategory(category);
                _loadPage(1);
              },
              selectedColor: const Color(0xFFFF6B6B),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              elevation: selected ? 4 : 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: selected ? Colors.transparent : Colors.grey.shade200,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagination(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _pageButton(
            icon: Icons.chevron_left,
            onPressed: provider.hasPrevious ? () => _loadPage(provider.currentPage - 1) : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              '${provider.currentPage} / ${provider.totalPages}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _pageButton(
            icon: Icons.chevron_right,
            onPressed: provider.hasNext ? () => _loadPage(provider.currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _pageButton({required IconData icon, required VoidCallback? onPressed}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: onPressed == null ? Colors.grey : const Color(0xFFFF6B6B)),
        ),
      ),
    );
  }
}

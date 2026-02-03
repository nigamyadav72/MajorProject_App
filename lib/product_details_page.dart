import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:majorproject_app/services/khalti_helper.dart';

import 'models/product.dart';
import 'models/product_detail.dart';

import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'services/api_service.dart';
import 'utils/image_url.dart';

class ProductDetailsPage extends StatefulWidget {
  final String productId;
  final Product? initialProduct;

  const ProductDetailsPage({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  ProductDetail? _detail;
  bool _loading = true;
  String? _error;

  static const _colors = ['Black', 'White', 'Gray', 'Blue'];
  static const _sizes = ['S', 'M', 'L', 'XL', '2XL', '3XL'];

  int _selectedColorIndex = 0;
  int _selectedSizeIndex = 1; // M
  int _quantity = 1;
  int _selectedImageIndex = 0;
  int _tabIndex = 0;

  bool _bottomBarVisible = true;
  Timer? _hideBarTimer;
  VoidCallback? _scrollEndListener;
  bool _scrollListenerAttached = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hideBarTimer?.cancel();
    _detachScrollListeners();
    _scrollController.dispose();
    super.dispose();
  }

  void _attachScrollListeners() {
    if (!mounted || !_scrollController.hasClients || _scrollListenerAttached) {
      return;
    }
    _scrollEndListener ??= () {
      _hideBarTimer?.cancel();
      if (_scrollController.position.isScrollingNotifier.value) {
        if (!_bottomBarVisible && mounted) {
          setState(() => _bottomBarVisible = true);
        }
      } else {
        _hideBarTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted && _bottomBarVisible) {
            setState(() => _bottomBarVisible = false);
          }
        });
      }
    };
    _scrollController.position.isScrollingNotifier
        .addListener(_scrollEndListener!);
    _scrollListenerAttached = true;
  }

  void _detachScrollListeners() {
    if (!_scrollListenerAttached || _scrollEndListener == null) return;
    if (_scrollController.hasClients) {
      _scrollController.position.isScrollingNotifier
          .removeListener(_scrollEndListener!);
    }
    _scrollListenerAttached = false;
  }

  void _onTouchShowBar() {
    _hideBarTimer?.cancel();
    if (!_bottomBarVisible && mounted) setState(() => _bottomBarVisible = true);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = await _api.fetchProductDetail(int.parse(widget.productId));
    if (!mounted) return;
    setState(() {
      _detail = d;
      _loading = false;
      if (d == null) _error = 'Could not load product';
    });
  }

  Product get _product => _detail?.product ?? widget.initialProduct!;

  bool get _hasProduct => _detail != null || widget.initialProduct != null;

  List<String> get _imageUrls {
    if (_detail != null && _detail!.imageUrls.isNotEmpty) {
      return _detail!.imageUrls;
    }
    if (widget.initialProduct != null &&
        widget.initialProduct!.imageUrl.isNotEmpty) {
      return [resolveImageUrl(widget.initialProduct!.imageUrl)];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasProduct && !_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product')),
        body: const Center(child: Text('Product not found')),
      );
    }

    if (_hasProduct && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _attachScrollListeners();
      });
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _loading && !_hasProduct
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Listener(
                  onPointerDown: (_) => _onTouchShowBar(),
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImageSection(),
                          if (_error != null) _buildErrorBanner(),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTitleRating(),
                                const SizedBox(height: 12),
                                _buildPrice(),
                                const SizedBox(height: 20),
                                _buildColorSection(),
                                const SizedBox(height: 16),
                                _buildSizeSection(),
                                const SizedBox(height: 16),
                                _buildQuantitySection(),
                                const SizedBox(height: 20),
                                _buildActionButtons(),
                                const SizedBox(height: 16),
                                _buildChatWishlistShare(),
                                const SizedBox(height: 24),
                                _buildSellerCard(),
                                const SizedBox(height: 20),
                                _buildPolicies(),
                                const SizedBox(height: 24),
                                _buildTabs(),
                                const SizedBox(height: 16),
                                _buildTabContent(),
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomBar(),
                ),
              ],
            ),
    );
  }

  Widget _buildBottomBar() {
    final outOfStock = _product.stockStatus == 'out_of_stock';
    return AnimatedSlide(
      offset: _bottomBarVisible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: _bottomBarVisible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !_bottomBarVisible,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: outOfStock ? null : _buyNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Buy this Item'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: outOfStock ? null : _addToCart,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add to Cart'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Product',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.black),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final urls = _imageUrls;
    if (urls.isEmpty) {
      return Container(
        height: 320,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: CachedNetworkImage(
            imageUrl: urls[_selectedImageIndex],
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.image_not_supported,
              size: 48,
              color: Colors.grey,
            ),
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: urls.length,
              itemBuilder: (context, i) {
                final sel = i == _selectedImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageIndex = i),
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: sel ? Colors.black : Colors.grey.shade300,
                        width: sel ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: CachedNetworkImage(
                        imageUrl: urls[i],
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.image),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTitleRating() {
    final p = _product;
    final category = p.categories.isNotEmpty ? p.categories.first : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category.isNotEmpty)
          Text(
            category,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        if (category.isNotEmpty) const SizedBox(height: 4),
        Text(
          p.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...List.generate(
              5,
              (i) => Icon(
                i < p.rating.floor() ? Icons.star : Icons.star_border,
                size: 18,
                color: Colors.amber,
              ),
            ),
            Text(
              '(${p.ratingCount} reviews)',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const Text(
              '10K+ Sold',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrice() {
    return Text(
      '₹${_product.price.toStringAsFixed(2)}',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildColorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Color',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: List.generate(_colors.length, (i) {
            final sel = i == _selectedColorIndex;
            return Material(
              color: sel ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Colors.grey.shade300,
                  width: sel ? 0 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => setState(() => _selectedColorIndex = i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    _colors[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Size',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Size guide')),
                );
              },
              child: const Text(
                'Size Guide',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: List.generate(_sizes.length, (i) {
            final sel = i == _selectedSizeIndex;
            return Material(
              color: sel ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Colors.grey.shade300,
                  width: sel ? 0 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => setState(() => _selectedSizeIndex = i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    _sizes[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildQuantitySection() {
    return Row(
      children: [
        const Text(
          'Quantity:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  if (_quantity > 1) setState(() => _quantity--);
                },
                icon: const Icon(Icons.remove),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final outOfStock = _product.stockStatus == 'out_of_stock';
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: outOfStock ? null : _buyNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Buy this Item'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: outOfStock ? null : _addToCart,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add to Cart'),
          ),
        ),
      ],
    );
  }

  Future<void> _buyNow() async {
    await KhaltiHelper().buyNow(
      context,
      productId: _product.id,
      productName: _product.name,
      price: _product.price,
      quantity: _quantity,
    );
  }

  Future<void> _addToCart() async {
    final p = _product;
    final cart = context.read<CartProvider>();
    await cart.addToCart(int.parse(p.id), quantity: _quantity);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.name} added to cart'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
  }

  Widget _buildChatWishlistShare() {
    return Consumer<WishlistProvider>(
      builder: (context, wishlist, _) {
        final inWishlist = wishlist.isInWishlist(_product.id);
        return Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _actionChip(Icons.chat_bubble_outline, 'Chat', () {}),
            _actionChip(
              inWishlist ? Icons.favorite : Icons.favorite_border,
              'Wishlist',
              () {
                if (inWishlist) {
                  wishlist.removeFromWishlist(_product.id);
                } else {
                  wishlist.addToWishlist(_product);
                }
              },
              isHighlight: inWishlist,
            ),
            _actionChip(Icons.share_outlined, 'Share', () {}),
          ],
        );
      },
    );
  }

  Widget _actionChip(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isHighlight ? Colors.red : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isHighlight ? Colors.red : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Barudak Disaster Mall',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
              ),
              const Text('Online', style: TextStyle(fontSize: 13)),
              Text(
                'Rating Store: 96%',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Chat Reply: 98%',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Location Store: Tulungagung',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Follow'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Visit Store'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolicies() {
    return Row(
      children: [
        Expanded(
          child: _policyItem(
            Icons.local_shipping_outlined,
            'Free Delivery',
            'Orders over ₹500',
          ),
        ),
        Expanded(
          child: _policyItem(
            Icons.verified_user_outlined,
            '1 Year Warranty',
            'Manufacturer warranty',
          ),
        ),
        Expanded(
          child: _policyItem(
            Icons.loop,
            'Easy Returns',
            '7-day return policy',
          ),
        ),
      ],
    );
  }

  Widget _policyItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.grey.shade700),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTabs() {
    const labels = ['Description', 'Styling Ideas', 'Review', 'Best Seller'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(labels.length, (i) {
                final sel = i == _tabIndex;
                return GestureDetector(
                  onTap: () => setState(() => _tabIndex = i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                            color: sel ? Colors.black : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 2,
                          width: 60,
                          color: sel ? Colors.black : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {},
          child: const Text(
            'Report Product',
            style: TextStyle(
              fontSize: 13,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductDetailsCard() {
    final attrs = _detail?.attributes ?? [];
    final List<({String name, String value})> rows = attrs.isNotEmpty
        ? attrs
        : [
            (name: 'Package Dimensions', value: '—'),
            (name: 'Specification', value: '—'),
            (name: 'Date First Available', value: '—'),
            (
              name: 'Department',
              value: _product.categories.isNotEmpty
                  ? _product.categories.first
                  : '—'
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        rows[i].name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        rows[i].value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                if (i < rows.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Colors.grey.shade200),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 0:
        final desc = _product.description;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              desc.isEmpty
                  ? 'No description available for this product.'
                  : desc,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildProductDetailsCard(),
          ],
        );
      case 1:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Styling ideas coming soon.'),
          ),
        );
      case 2:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No reviews yet.'),
          ),
        );
      case 3:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Best seller products coming soon.'),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

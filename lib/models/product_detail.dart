import 'product.dart';
import '../utils/image_url.dart';

/// Product detail from GET /api/products/<id>/ (images, attributes, reviews).
class ProductDetail {
  final Product product;
  final List<String> imageUrls;
  final List<({String name, String value})> attributes;

  ProductDetail({
    required this.product,
    required this.imageUrls,
    required this.attributes,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final product = Product.fromJson(json);
    final List<String> urls = [];
    final rawImages = json['images'] as List<dynamic>? ?? [];
    for (final im in rawImages) {
      final m = im as Map<String, dynamic>;
      final path = m['image']?.toString();
      if (path != null && path.isNotEmpty) {
        urls.add(resolveImageUrl(path));
      }
    }
    if (urls.isEmpty && product.imageUrl.isNotEmpty) {
      urls.add(resolveImageUrl(product.imageUrl));
    }

    final List<({String name, String value})> attrs = [];
    for (final a in json['attributes'] as List<dynamic>? ?? []) {
      final m = a as Map<String, dynamic>;
      final name = m['name']?.toString() ?? '';
      final value = m['value']?.toString() ?? '';
      if (name.isNotEmpty) attrs.add((name: name, value: value));
    }

    return ProductDetail(
      product: product,
      imageUrls: urls,
      attributes: attrs,
    );
  }
}

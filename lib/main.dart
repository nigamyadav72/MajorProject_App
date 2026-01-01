import 'package:flutter/material.dart';
import 'screens/product_detail_screen.dart';

void main() {
  runApp(const EPasalApp());
}

class EPasalApp extends StatelessWidget {
  const EPasalApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-Pasal',
      home: ProductDetailScreen(
        product: {
          'id': 1,
          'name': 'Sample Product',
          'price': 1200,
          'original_price': 1500,
          'rating': 4,
          'reviews_count': 25,
          'description': 'This is a demo product description.',
          'image': 'https://via.placeholder.com/400',
          'in_stock': true,
          'specifications': {
            'Brand': 'E-Pasal',
            'Color': 'Black',
            'Warranty': '1 Year',
          },
        },
      ),
    );
  }
}

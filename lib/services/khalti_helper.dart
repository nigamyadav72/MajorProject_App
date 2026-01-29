import 'package:flutter/material.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../screens/payment_success_page.dart';

class KhaltiHelper {
  final ApiService _api = ApiService();

  Future<void> buyNow(BuildContext context, {
    required String productId,
    required String productName,
    required double price,
    required int quantity,
  }) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue')),
      );
      return;
    }

    try {
      // 1. Initiate Payment
      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: '9800000000',
        amount: price * quantity,
        productId: productId,
        productName: productName,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      // 2. Launch SDK
      if (!context.mounted) return;
      await _launchKhalti(context, pidx);

    } catch (e, stackTrace) {
      if (!context.mounted) return;
      debugPrint('❌ Khalti Payment Error: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating payment: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> checkout(BuildContext context, CartProvider cart) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue')),
      );
      return;
    }

    try {
      // 1. Initiate
      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: '9800000000',
        amount: cart.totalPrice,
        productId: 'cart_order_${DateTime.now().millisecondsSinceEpoch}',
        productName: 'Cart Checkout',
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      // 2. Launch SDK
      if (!context.mounted) return;
      await _launchKhalti(context, pidx, onSuccess: () {
        cart.clearCart();
      });

    } catch (e, stackTrace) {
      if (!context.mounted) return;
      debugPrint('❌ Khalti Payment Error: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating payment: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _launchKhalti(BuildContext context, String pidx, {VoidCallback? onSuccess}) async {
    final config = KhaltiPayConfig(
      publicKey: 'test_public_key_dc74e0d5440a45d098e984f4dc15dc35',
      pidx: pidx,
      environment: Environment.test,
    );

    final khalti = await Khalti.init(
      payConfig: config,
      onPaymentResult: (paymentResult, khaltiInstance) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Successful!')),
        );
        
        if (onSuccess != null) onSuccess();
        
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
        );
      },
      onMessage: (
        khaltiInstance, {
        int? statusCode,
        Object? description,
        KhaltiEvent? event,
        bool? needsPaymentConfirmation,
      }) {
        if (description != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(description.toString())),
          );
        }
      },
      onReturn: () {
        // User returned/cancelled
      },
      enableDebugging: true,
    );

    if (!context.mounted) return;
    khalti.open(context);
  }
}

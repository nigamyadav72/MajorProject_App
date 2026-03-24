import 'package:flutter/material.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../screens/payment_success_page.dart';
import '../screens/payment_cancel_page.dart';

class KhaltiHelper {
  final ApiService _api = ApiService();

  Future<void> buyNow(
    BuildContext context, {
    required String productId,
    required String productName,
    required double price,
    required int quantity,
    String? sku,
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
      debugPrint('🚀 Initiating Buy Now payment for $productName at ₹$price x $quantity');
      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: auth.user?.phoneNumber.isNotEmpty == true ? auth.user!.phoneNumber : '9800000000',
        amount: price * quantity,
        productId: productId,
        productName: productName,
        // Note: Mobile SDK uses onPaymentResult callback, doesn't redirect to these URLs
        // These are for web compatibility and Khalti API validation
        returnUrl: '${AppConfig.backendBaseUrl}/api/payment/success/',
        websiteUrl: AppConfig.backendBaseUrl,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      // 2. Launch SDK
      if (!context.mounted) return;
      await _launchKhalti(context, pidx, onSuccess: () async {
        // Create order on backend for Buy Now (single product)
        try {
          debugPrint('📦 Creating Buy Now order on backend...');
          await _api.createOrder(
            shippingAddress: auth.user?.address.isNotEmpty == true 
                ? auth.user!.address 
                : (auth.user?.email ?? 'TBD'),
            transactionId: pidx,
            buyNowProductId: productId,
            buyNowProductSku: sku,
            qty: quantity,
          );
          debugPrint('✅ Order created successfully');
        } catch (e) {
          debugPrint('❌ Error creating order: $e');
          // Don't block the success flow
        }
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
      debugPrint('🚀 Initiating Cart checkout for ₹${cart.totalPrice}');
      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: auth.user?.phoneNumber.isNotEmpty == true ? auth.user!.phoneNumber : '9800000000',
        amount: cart.totalPrice,
        productId: 'cart_order_${DateTime.now().millisecondsSinceEpoch}',
        productName: 'Cart Checkout',
        // Note: Mobile SDK uses onPaymentResult callback, doesn't redirect to these URLs
        // These are for web compatibility and Khalti API validation
        returnUrl: '${AppConfig.backendBaseUrl}/api/payment/success/',
        websiteUrl: AppConfig.backendBaseUrl,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      // 2. Launch SDK
      if (!context.mounted) return;
      await _launchKhalti(context, pidx, onSuccess: () async {
        // Create order on backend after successful payment
        try {
          debugPrint('📦 Creating order on backend...');
          await _api.createOrder(
            shippingAddress: auth.user?.address.isNotEmpty == true 
                ? auth.user!.address 
                : (auth.user?.email ?? 'TBD'),
            transactionId: pidx,
          );
          debugPrint('✅ Order created successfully');
          
          // Clear cart after order is created
          await cart.clearCart();
          debugPrint('🛒 Cart cleared');
        } catch (e) {
          debugPrint('❌ Error creating order: $e');
          // Don't block the flow, still clear cart and show success
          await cart.clearCart();
        }
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
}

Future<void> _launchKhalti(BuildContext context, String pidx,
    {VoidCallback? onSuccess}) async {
  bool handled = false;

  final config = KhaltiPayConfig(
    publicKey: 'test_public_key_dc74e0d5440a45d098e984f4dc15dc35',
    pidx: pidx,
    environment: Environment.test,
  );

  final khalti = await Khalti.init(
    payConfig: config,
    onPaymentResult: (paymentResult, khaltiInstance) {
      if (handled) return;
      handled = true;

      debugPrint('✅ Khalti Payment Result Received: $paymentResult');
      
      khaltiInstance.close(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful!')),
      );

      if (onSuccess != null) onSuccess();

      debugPrint('🚀 Navigating to PaymentSuccessPage...');
      
      Navigator.of(context).pushReplacement(
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
      debugPrint(
          '📨 Khalti Message - Event: $event, Description: $description');
          
      // Only close and mark handled if it's a terminal event or network error
      if (event == KhaltiEvent.networkFailure || event?.name == 'error') {
        if (!handled) {
          handled = true;
          khaltiInstance.close(context);
          if (description != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(description.toString())),
            );
          }
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaymentCancelPage(message: description?.toString()),
            ),
          );
        }
      } else {
        // Just show message for other events without closing
        if (description != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(description.toString())),
          );
        }
      }
    },
    onReturn: () {
      debugPrint('🔙 User returned from payment WebView');
      
      if (!handled && context.mounted) {
        handled = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Cancelled or Interrupted')),
        );

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentCancelPage()),
        );
      }
    },
    enableDebugging: true,
  );

  if (!context.mounted) return;
  khalti.open(context);
}

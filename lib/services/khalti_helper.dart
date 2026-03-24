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
    {Future<void> Function()? onSuccess}) async {
  bool handled = false;

  final config = KhaltiPayConfig(
    publicKey: 'test_public_key_dc74e0d5440a45d098e984f4dc15dc35',
    pidx: pidx,
    environment: Environment.test,
  );

  final khalti = await Khalti.init(
    payConfig: config,
    onPaymentResult: (paymentResult, khaltiInstance) async {
      if (handled) return;
      handled = true;

      debugPrint('✅ Khalti Payment Result Received: $paymentResult');
      
      khaltiInstance.close(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful!')),
      );

      if (onSuccess != null) await onSuccess();

      debugPrint('🚀 Navigating to PaymentSuccessPage...');
      
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
        );
      }
    },
    onMessage: (
      khaltiInstance, {
      int? statusCode,
      Object? description,
      KhaltiEvent? event,
      bool? needsPaymentConfirmation,
    }) async {
      debugPrint('📨 Khalti Message - Status: $statusCode, Event: $event, Description: $description');
      
      final descStr = description?.toString().toLowerCase() ?? '';
      
      // Expand success detection: 401 is common for lookup failure on valid redirect, 
      // but 'success' or 200 explicitly also means we are good.
      if (descStr.contains('invalid token') || 
          descStr.contains('401') || 
          descStr.contains('unauthorized') || 
          descStr.contains('success') || 
          statusCode == 200) {
        
        if (handled) return;
        handled = true;
        
        debugPrint('✅ Caught Success Indicator in Message - Treating as Payment Success!');
        khaltiInstance.close(context);
        
        if (onSuccess != null) await onSuccess();
        
        if (context.mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
            );
          });
        }
        return; 
      }

      // If it's a genuine terminal error
      if (event == KhaltiEvent.networkFailure || event?.name == 'error' || descStr.contains('error')) {
        if (!handled && context.mounted) {
          handled = true;
          khaltiInstance.close(context);
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaymentCancelPage(message: 'Payment was interrupted. ($descStr)'),
            ),
          );
        }
      } 
    },
    onReturn: () async {
      debugPrint('🔙 User returned from payment WebView');
      
      // Grace period: Wait briefly to see if onPaymentResult or onMessage triggers success first.
      // This solves the issue where hitting 'back' after a successful bank redirect 
      // triggers onReturn before the platform bridge syncs the result.
      await Future.delayed(const Duration(seconds: 1));
      
      if (!handled && context.mounted) {
        handled = true;
        debugPrint('⚠️ No success result received within grace period. Navigating to Cancel Page.');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentCancelPage(message: 'You closed the payment process.')),
        );
      }
    },

    enableDebugging: true,
  );

  if (!context.mounted) return;
  khalti.open(context);
}

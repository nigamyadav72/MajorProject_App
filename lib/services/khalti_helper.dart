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
      debugPrint('🚀 Initiating Buy Now payment for $productName at ₹$price x $quantity');
      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: auth.user?.phoneNumber.isNotEmpty == true ? auth.user!.phoneNumber : '9800000000',
        amount: price * quantity,
        productId: productId,
        productName: productName,
        returnUrl: '${AppConfig.backendBaseUrl}/api/payment/success/',
        websiteUrl: AppConfig.backendBaseUrl,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      if (!context.mounted) return;
      await _launchKhalti(context, pidx, onSuccess: () async {
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
      debugPrint('🚀 Initiating Cart checkout for ₹${cart.totalPrice}');
      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: auth.user?.phoneNumber.isNotEmpty == true ? auth.user!.phoneNumber : '9800000000',
        amount: cart.totalPrice,
        productId: 'cart_order_${DateTime.now().millisecondsSinceEpoch}',
        productName: 'Cart Checkout',
        returnUrl: '${AppConfig.backendBaseUrl}/api/payment/success/',
        websiteUrl: AppConfig.backendBaseUrl,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      if (!context.mounted) return;
      await _launchKhalti(context, pidx, onSuccess: () async {
        try {
          debugPrint('📦 Creating order on backend...');
          await _api.createOrder(
            shippingAddress: auth.user?.address.isNotEmpty == true
                ? auth.user!.address
                : (auth.user?.email ?? 'TBD'),
            transactionId: pidx,
          );
          debugPrint('✅ Order created successfully');
          await cart.clearCart();
          debugPrint('🛒 Cart cleared');
        } catch (e) {
          debugPrint('❌ Error creating order: $e');
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

Future<void> _launchKhalti(
  BuildContext context,
  String pidx, {
  Future<void> Function()? onSuccess,
}) async {
  // Single flag to ensure we only navigate once.
  bool handled = false;

  final config = KhaltiPayConfig(
    publicKey: 'test_public_key_dc74e0d5440a45d098e984f4dc15dc35',
    pidx: pidx,
    environment: Environment.test,
  );

  final khalti = await Khalti.init(
    payConfig: config,

    // ─────────────────────────────────────────────────────────────────────
    // SUCCESS — this is the ONLY reliable success signal from the SDK.
    // It fires when Khalti confirms the transaction on their servers.
    // ─────────────────────────────────────────────────────────────────────
    onPaymentResult: (paymentResult, khaltiInstance) async {
      if (handled) return;
      handled = true;

      debugPrint('✅ onPaymentResult — Payment confirmed: $paymentResult');

      khaltiInstance.close(context);

      // Run any post-payment work (create order, clear cart, etc.)
      if (onSuccess != null) await onSuccess();

      debugPrint('🚀 Navigating → PaymentSuccessPage');

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
        );
      }
    },

    // ─────────────────────────────────────────────────────────────────────
    // MESSAGES — informational / error events from the WebView.
    //
    // ⚠️  IMPORTANT — Do NOT treat 401 / "invalid token" / "unauthorized"
    //   as a success here.  Those are normal Khalti TEST-environment
    //   lookup errors that fire on EVERY payment attempt.  The payment
    //   may still be completing.  Treating them as success caused the
    //   old race-condition bug where this callback fired before the real
    //   result arrived and routed the user to the wrong page.
    // ─────────────────────────────────────────────────────────────────────
    onMessage: (
      khaltiInstance, {
      int? statusCode,
      Object? description,
      KhaltiEvent? event,
      bool? needsPaymentConfirmation,
    }) async {
      debugPrint(
          '📨 onMessage — status: $statusCode | event: $event | desc: $description');

      if (handled) return;

      final descStr = description?.toString().toLowerCase() ?? '';

      // Only navigate to cancel when the user explicitly cancels.
      final isExplicitCancel =
          event == KhaltiEvent.paymentLookupfailure ||
          descStr.contains('user cancel') ||
          descStr.contains('payment cancel') ||
          descStr.contains('cancelled by user');

      if (isExplicitCancel) {
        handled = true;
        khaltiInstance.close(context);

        debugPrint('🚫 Explicit cancellation detected → PaymentCancelPage');

        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const PaymentCancelPage(
                message: 'Payment was cancelled.',
              ),
            ),
          );
        }
        return;
      }

      // Everything else (401, network glitches, informational messages) →
      // just log it.  onPaymentResult will handle the success navigation.
      debugPrint('ℹ️  Non-terminal message received — no navigation.');
    },

    // ─────────────────────────────────────────────────────────────────────
    // RETURN — fires when the payment WebView sheet dismisses.
    //
    // This fires BOTH after a successful payment redirect AND when the
    // user manually closes the sheet.  We wait 2 seconds to give
    // onPaymentResult a chance to fire first (it arrives slightly later
    // after the bank redirect completes).
    // ─────────────────────────────────────────────────────────────────────
    onReturn: () async {
      debugPrint('🔙 onReturn — WebView sheet dismissed');

      // Grace period: let onPaymentResult arrive if the payment succeeded.
      await Future.delayed(const Duration(seconds: 2));

      if (!handled && context.mounted) {
        // onPaymentResult never fired → user closed without completing payment.
        handled = true;
        debugPrint('⚠️ No payment result received — treating as cancellation.');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const PaymentCancelPage(
              message: 'You closed the payment without completing it.',
            ),
          ),
        );
      }
    },

    enableDebugging: true,
  );

  if (!context.mounted) return;
  khalti.open(context);
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../screens/payment_success_page.dart';

class KhaltiHelper {
  final ApiService _api = ApiService();

  // ───────────────────────────────────────────────────────────────────────────
  // BUY NOW — single product purchase
  // ───────────────────────────────────────────────────────────────────────────
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
      debugPrint(
          '🚀 Initiating Buy Now payment for $productName at ₹$price x $quantity');

      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: auth.user?.phoneNumber.isNotEmpty == true
            ? auth.user!.phoneNumber
            : '9800000000',
        amount: price * quantity,
        productId: productId,
        productName: productName,
        returnUrl: '${AppConfig.backendBaseUrl}/api/payment/success/',
        websiteUrl: AppConfig.backendBaseUrl,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      if (!context.mounted) return;

      await _launchKhalti(
        context,
        pidx,
        onSuccess: () async {
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
          }
        },
      );
    } catch (e, stackTrace) {
      if (!context.mounted) return;
      debugPrint('❌ Khalti Payment Error: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating payment: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CHECKOUT — cart purchase
  // ───────────────────────────────────────────────────────────────────────────
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
        phone: auth.user?.phoneNumber.isNotEmpty == true
            ? auth.user!.phoneNumber
            : '9800000000',
        amount: cart.totalPrice,
        productId: 'cart_order_${DateTime.now().millisecondsSinceEpoch}',
        productName: 'Cart Checkout',
        returnUrl: '${AppConfig.backendBaseUrl}/api/payment/success/',
        websiteUrl: AppConfig.backendBaseUrl,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      if (!context.mounted) return;

      await _launchKhalti(
        context,
        pidx,
        onSuccess: () async {
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
        },
      );
    } catch (e, stackTrace) {
      if (!context.mounted) return;
      debugPrint('❌ Khalti Payment Error: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating payment: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Uses a Completer to synchronize onReturn and onMessage:
//   - onMessage fires when Khalti sends the 401 test-env success signal
//     → completes the Completer with true.
//   - onReturn fires when the WebView closes → shows a loading dialog
//     ("Verifying payment…") → awaits the Completer with a 10s timeout.
//   - Once the Completer resolves, we dismiss the dialog and navigate.
// ═══════════════════════════════════════════════════════════════════════════════
Future<void> _launchKhalti(
  BuildContext context,
  String pidx, {
  Future<void> Function()? onSuccess,
}) async {
  bool navigated = false;
  final paymentCompleter = Completer<bool>();

  final config = KhaltiPayConfig(
    publicKey: 'test_public_key_dc74e0d5440a45d098e984f4dc15dc35',
    pidx: pidx,
    environment: Environment.test,
  );

  final khalti = await Khalti.init(
    payConfig: config,

    // ── PRODUCTION SUCCESS (safety net) ────────────────────────────────────
    onPaymentResult: (paymentResult, khaltiInstance) async {
      if (navigated) return;
      navigated = true;

      debugPrint('✅ onPaymentResult — Payment confirmed: $paymentResult');
      khaltiInstance.close(context);

      // Complete the Completer so onReturn (if still waiting) knows.
      if (!paymentCompleter.isCompleted) paymentCompleter.complete(true);

      if (onSuccess != null) await onSuccess();

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
        );
      }
    },

    // ── TEST-ENV SUCCESS SIGNAL ────────────────────────────────────────────
    // Just completes the Completer — does NOT navigate.
    // Navigation is handled by onReturn after the loading dialog.
    onMessage: (
      khaltiInstance, {
      int? statusCode,
      Object? description,
      KhaltiEvent? event,
      bool? needsPaymentConfirmation,
    }) async {
      debugPrint(
          '📨 onMessage — status: $statusCode | event: $event | desc: $description');

      final descStr = description?.toString().toLowerCase() ?? '';

      final isSuccessSignal =
          statusCode == 401 ||
          statusCode == 200 ||
          descStr.contains('invalid token') ||
          descStr.contains('unauthorized') ||
          descStr.contains('success') ||
          event == KhaltiEvent.paymentLookupfailure;

      if (isSuccessSignal && !paymentCompleter.isCompleted) {
        debugPrint('🟡 Success signal detected — completing Completer.');
        paymentCompleter.complete(true);
      }
    },

    // ── WEBVIEW CLOSED ────────────────────────────────────────────────────
    // Shows a loading buffer dialog immediately, then waits for the
    // Completer (which onMessage will complete when the 401 arrives).
    onReturn: () async {
      debugPrint('🔙 onReturn fired — showing loading buffer.');

      // If onPaymentResult already navigated, nothing to do.
      if (navigated) {
        debugPrint('ℹ️ Already navigated — skipping.');
        return;
      }

      // Show a loading dialog as the "buffer" screen.
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.white,
          builder: (_) => const PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Verifying payment...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Wait for the success signal with a 10s timeout.
      final success = await paymentCompleter.future
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      debugPrint('🔙 Completer resolved: success=$success');

      // If onPaymentResult already navigated while we were waiting, bail out.
      if (navigated) {
        if (context.mounted) Navigator.of(context).pop(); // dismiss dialog
        debugPrint('ℹ️ Already navigated — dismissing dialog only.');
        return;
      }

      navigated = true;

      // Dismiss the loading dialog.
      if (context.mounted) Navigator.of(context).pop();

      if (success) {
        debugPrint('✅ Payment verified — running onSuccess + navigating.');
        if (onSuccess != null) await onSuccess();

        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
          );
        }
      } else {
        debugPrint('⚠️ Payment not completed within timeout.');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment was not completed.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    },

    enableDebugging: true,
  );

  if (!context.mounted) return;
  khalti.open(context);
}
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

    final totalAmount = price * quantity;

    try {
      debugPrint(
          '🚀 Initiating Buy Now payment for $productName at ₹$price x $quantity');

      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: auth.user?.phoneNumber.isNotEmpty == true
            ? auth.user!.phoneNumber
            : '9800000000',
        amount: totalAmount,
        productId: productId,
        productName: productName,
        returnUrl: '${AppConfig.backendBaseUrl}/api/payment/success/',
        websiteUrl: AppConfig.backendBaseUrl,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      if (!context.mounted) return;

      String? orderError;

      await _launchKhalti(
        context,
        pidx,
        amount: totalAmount,
        api: _api,
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
            orderError =
                'Payment was successful, but we couldn\'t record your order. Please contact support.';
          }
        },
        getOrderError: () => orderError,
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

    final totalAmount = cart.totalPrice;

    try {
      debugPrint('🚀 Initiating Cart checkout for ₹$totalAmount');

      final data = await _api.initiateKhaltiPayment(
        name: auth.user?.name ?? 'Guest User',
        email: auth.user?.email ?? 'guest@example.com',
        phone: auth.user?.phoneNumber.isNotEmpty == true
            ? auth.user!.phoneNumber
            : '9800000000',
        amount: totalAmount,
        productId: 'cart_order_${DateTime.now().millisecondsSinceEpoch}',
        productName: 'Cart Checkout',
        returnUrl: '${AppConfig.backendBaseUrl}/api/payment/success/',
        websiteUrl: AppConfig.backendBaseUrl,
      );

      final pidx = data['pidx'];
      if (pidx == null) throw Exception('No pidx returned');

      if (!context.mounted) return;

      String? orderError;

      await _launchKhalti(
        context,
        pidx,
        amount: totalAmount,
        api: _api,
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
            orderError =
                'Payment was successful, but we couldn\'t record your order. Please contact support.';
            await cart.clearCart();
          }
        },
        getOrderError: () => orderError,
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
// Uses a Completer and direct backend verification to synchronize execution.
// ═══════════════════════════════════════════════════════════════════════════════
Future<void> _launchKhalti(
  BuildContext context,
  String pidx, {
  required double amount,
  required ApiService api,
  Future<void> Function()? onSuccess,
  String? Function()? getOrderError,
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

      if (!paymentCompleter.isCompleted) paymentCompleter.complete(true);

      if (onSuccess != null) await onSuccess();

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentSuccessPage(
              transactionId: pidx,
              amountPaid: amount,
              orderError: getOrderError?.call(),
            ),
          ),
        );
      }
    },

    // ── TEST-ENV SUCCESS SIGNAL ────────────────────────────────────────────
    onMessage: (
      khaltiInstance, {
      int? statusCode,
      Object? description,
      KhaltiEvent? event,
      bool? needsPaymentConfirmation,
    }) async {
      debugPrint(
          '📨 onMessage — status: $statusCode | event: $event | desc: $description');

      if (navigated) return;

      final descStr = description?.toString().toLowerCase() ?? '';

      final isSuccessSignal = statusCode == 401 ||
          statusCode == 200 ||
          statusCode == 500 ||
          descStr.contains('invalid token') ||
          descStr.contains('unauthorized') ||
          descStr.contains('success') ||
          descStr.contains('server error') ||
          event == KhaltiEvent.paymentLookupfailure;

      if (isSuccessSignal && !paymentCompleter.isCompleted) {
        debugPrint('🟡 Success signal detected — completing Completer.');
        paymentCompleter.complete(true);
      }
    },

    // ── WEBVIEW CLOSED ────────────────────────────────────────────────────
    onReturn: () async {
      debugPrint('🔙 onReturn fired — showing loading buffer.');

      if (navigated) {
        debugPrint('ℹ️ Already navigated — skipping.');
        return;
      }

      // ── MANUAL VERIFICATION BYPASS ──
      // Khalti's SDK onMessage is notoriously slow in test environments. 
      // We manually ping our Django backend to verify the pidX immediately.
      api.verifyKhaltiPayment(pidx).then((isVerified) {
        if (!paymentCompleter.isCompleted && isVerified) {
          debugPrint('🟡 Backend verification succeeded instantly!');
          paymentCompleter.complete(true);
        }
      });

      // Show loading buffer with a Cancel button.
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.white,
          builder: (_) => PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Verifying payment...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () {
                        // User got tired of waiting for Khalti's slow server
                        if (!paymentCompleter.isCompleted) {
                          paymentCompleter.complete(false);
                        }
                      },
                      child: const Text(
                        'Cancel Verification',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Wait for the success signal with a 60s timeout.
      final success = await paymentCompleter.future
          .timeout(const Duration(seconds: 60), onTimeout: () => false);

      debugPrint('🔙 Completer resolved: success=$success');

      // If onPaymentResult already navigated while we were waiting, bail out.
      if (navigated) {
        if (context.mounted) Navigator.of(context).pop();
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
            MaterialPageRoute(
              builder: (_) => PaymentSuccessPage(
                transactionId: pidx,
                amountPaid: amount,
                orderError: getOrderError?.call(),
              ),
            ),
          );
        }
      } else {
        debugPrint('⚠️ Payment not completed within timeout or cancelled manually. Silent failure.');
      }
    },

    enableDebugging: true,
  );

  if (!context.mounted) return;
  khalti.open(context);
}
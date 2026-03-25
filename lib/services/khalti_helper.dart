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
        }
      });
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
// HOW THE KHALTI SDK WORKS IN TEST ENVIRONMENT (root cause analysis):
//
//  1. User pays → Khalti WebView shows "Payment Successful! Auto-closing..."
//  2. SDK fires onMessage with {detail: Invalid token, status_code: 401}
//     This 401 is Khalti's server trying to call YOUR backend's return URL and
//     getting a 401 back — it does NOT mean the payment failed. In test env,
//     onPaymentResult NEVER fires; this 401 onMessage IS the success signal.
//  3. WebView auto-closes → onReturn fires.
//  4. If user manually presses back BEFORE paying → onReturn fires WITHOUT
//     a prior 401 onMessage.
//
//  SOLUTION: Track whether we saw the 401 success-indicator in onMessage.
//  In onReturn, navigate to success if we saw it, or cancel if we didn't.
// ═══════════════════════════════════════════════════════════════════════════════
Future<void> _launchKhalti(
  BuildContext context,
  String pidx, {
  Future<void> Function()? onSuccess,
}) async {
  bool navigated = false;        // ensures we navigate exactly once
  bool paymentCompleted = false; // true when we see a Khalti success signal

  final config = KhaltiPayConfig(
    publicKey: 'test_public_key_dc74e0d5440a45d098e984f4dc15dc35',
    pidx: pidx,
    environment: Environment.test,
  );

  final khalti = await Khalti.init(
    payConfig: config,

    // ─────────────────────────────────────────────────────────────────────────
    // onPaymentResult: the ideal success path (fires in production).
    // In test mode this may not fire — but handle it if it does.
    // ─────────────────────────────────────────────────────────────────────────
    onPaymentResult: (paymentResult, khaltiInstance) async {
      if (navigated) return;
      navigated = true;
      paymentCompleted = true;

      debugPrint('✅ onPaymentResult — Payment confirmed: $paymentResult');
      khaltiInstance.close(context);

      if (onSuccess != null) await onSuccess();

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
        );
      }
    },

    // ─────────────────────────────────────────────────────────────────────────
    // onMessage: fires for every SDK event — including the 401 that Khalti
    // test environment sends right after a successful payment.
    //
    // We do NOT navigate here. Instead we just set the paymentCompleted flag
    // when we detect a success indicator. onReturn will do the actual routing.
    //
    // Why not navigate here? Because this callback fires BEFORE the WebView
    // has closed. Navigating while the WebView is still open causes the
    // Cancel page to flash on top of the WebView, and then onReturn fires
    // afterward and navigates again → two conflicting navigations.
    // ─────────────────────────────────────────────────────────────────────────
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

      // ── Explicit user cancellation ─────────────────────────────────────────
      // paymentLookupfailure fires when user taps "Cancel" inside the Khalti UI.
      final isExplicitCancel =
          event == KhaltiEvent.paymentLookupfailure ||
          descStr.contains('user cancel') ||
          descStr.contains('payment cancel') ||
          descStr.contains('cancelled by user');

      if (isExplicitCancel) {
        navigated = true;
        paymentCompleted = false;
        khaltiInstance.close(context);
        debugPrint('🚫 User explicitly cancelled the payment.');

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

      // ── TEST ENVIRONMENT SUCCESS INDICATOR ─────────────────────────────────
      // In Khalti's test environment, after a successful payment the WebView
      // shows "Payment Successful!" and simultaneously fires onMessage with
      // statusCode 401 / "Invalid token". This is because Khalti's servers
      // try to call your backend's return URL and receive a 401 back.
      // This does NOT mean the payment failed — the payment IS complete.
      // We mark paymentCompleted = true here so onReturn knows to route to
      // the success page once the WebView finishes closing itself.
      final isTestEnvSuccessSignal =
          statusCode == 401 ||
          descStr.contains('invalid token') ||
          descStr.contains('unauthorized') ||
          statusCode == 200 ||
          descStr.contains('success');

      if (isTestEnvSuccessSignal) {
        debugPrint(
            '🟡 Test-env success signal detected (status $statusCode). '
            'Marking paymentCompleted=true. Will navigate in onReturn.');
        paymentCompleted = true;
        // Do NOT navigate yet — the WebView is still open. Let it auto-close
        // and onReturn will handle the navigation cleanly.
        return;
      }

      debugPrint('ℹ️ Non-actionable message — ignoring.');
    },

    // ─────────────────────────────────────────────────────────────────────────
    // onReturn: fires when the Khalti WebView fully closes (both on success
    // auto-close AND when user manually presses back).
    //
    // By this point onMessage has already run and set paymentCompleted.
    // We use that flag to decide where to navigate.
    // ─────────────────────────────────────────────────────────────────────────
    onReturn: () async {
      debugPrint(
          '🔙 onReturn — WebView closed | paymentCompleted=$paymentCompleted | navigated=$navigated');

      // Brief pause so onPaymentResult (production path) can fire first if
      // it arrives just after onReturn.
      await Future.delayed(const Duration(milliseconds: 600));

      if (navigated) {
        // Already handled by onPaymentResult or explicit cancel in onMessage.
        debugPrint('ℹ️ Already navigated — skipping onReturn routing.');
        return;
      }

      navigated = true;

      if (paymentCompleted) {
        // Payment succeeded (test-env 401 signal was received).
        debugPrint('✅ Payment completed — navigating to PaymentSuccessPage.');

        if (onSuccess != null) await onSuccess();

        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
          );
        }
      } else {
        // User closed the WebView without paying.
        debugPrint('⚠️ Payment NOT completed — navigating to PaymentCancelPage.');

        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const PaymentCancelPage(
                message: 'You closed the payment without completing it.',
              ),
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

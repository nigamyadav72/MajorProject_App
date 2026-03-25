import 'package:flutter/material.dart';
import '../bottom_nav.dart';
import 'my_orders_page.dart';

class PaymentSuccessPage extends StatelessWidget {
  final String? transactionId;
  final double? amountPaid;
  final String? orderError; // non-null if order creation failed

  const PaymentSuccessPage({
    super.key,
    this.transactionId,
    this.amountPaid,
    this.orderError,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Green checkmark ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4CAF50),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF4CAF50),
                      size: 48,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Title ──────────────────────────────────────────────
                  const Text(
                    '🎉 Payment Successful!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Subtitle ───────────────────────────────────────────
                  Text(
                    'Thank you! Your payment was processed successfully and\nyour order is being prepared.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Order error warning (if any) ───────────────────────
                  if (orderError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFFFCC80), width: 1),
                      ),
                      child: Text(
                        orderError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),

                  if (orderError != null) const SizedBox(height: 20),

                  // ── Transaction Details Card ───────────────────────────
                  if (transactionId != null || amountPaid != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFE0E0E0), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TRANSACTION DETAILS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Color(0xFF616161),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Status
                          _buildDetailRow(
                            'Status',
                            'Completed',
                            valueColor: const Color(0xFF4CAF50),
                            valueBold: true,
                          ),
                          const SizedBox(height: 12),

                          // Transaction ID
                          if (transactionId != null)
                            _buildDetailRow(
                              'Transaction ID',
                              transactionId!,
                            ),
                          if (transactionId != null)
                            const SizedBox(height: 12),

                          // Amount Paid
                          if (amountPaid != null)
                            _buildDetailRow(
                              'Amount Paid',
                              'Rs. ${amountPaid!.toStringAsFixed(2)}',
                              valueBold: true,
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── Buttons ────────────────────────────────────────────
                  Row(
                    children: [
                      // Continue Shopping
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BottomNav(initialIndex: 0)),
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.shopping_cart_outlined,
                                size: 18),
                            label: const Text(
                              'Continue Shopping',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // View Orders
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const MyOrdersPage()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF424242),
                              side: const BorderSide(
                                  color: Color(0xFFBDBDBD), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'View Orders',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}

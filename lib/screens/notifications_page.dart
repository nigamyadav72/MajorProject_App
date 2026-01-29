import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _orderUpdates = true;
  bool _promotions = false;
  bool _newArrivals = true;
  bool _emailNotif = true;
  bool _smsNotif = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Notification Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _SettingCard(
            title: 'Order Updates',
            subtitle: 'Get notified about your order status',
            value: _orderUpdates,
            onChanged: (val) => setState(() => _orderUpdates = val),
          ),
          _SettingCard(
            title: 'Promotions & Offers',
            subtitle: 'Receive exclusive deals and discounts',
            value: _promotions,
            onChanged: (val) => setState(() => _promotions = val),
          ),
          _SettingCard(
            title: 'New Arrivals',
            subtitle: 'Be first to know about new products',
            value: _newArrivals,
            onChanged: (val) => setState(() => _newArrivals = val),
          ),
          const SizedBox(height: 24),
          const Text(
            'Delivery Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _SettingCard(
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: _emailNotif,
            onChanged: (val) => setState(() => _emailNotif = val),
          ),
          _SettingCard(
            title: 'SMS Notifications',
            subtitle: 'Receive notifications via SMS',
            value: _smsNotif,
            onChanged: (val) => setState(() => _smsNotif = val),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFFFF6B6B),
            ),
          ],
        ),
      ),
    );
  }
}

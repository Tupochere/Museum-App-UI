import 'package:flutter/material.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';
import '../events/notification_center_screen.dart';
import '../tickets/ticket_wallet_screen.dart';

class ProfilePreferencesScreen extends StatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  State<ProfilePreferencesScreen> createState() => _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState extends State<ProfilePreferencesScreen> {
  bool _english = true;
  bool _largeText = false;
  bool _highContrast = false;
  bool _eventAlerts = true;
  bool _tourReminders = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Profile & Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const OfflineBanner(),
          const SizedBox(height: 12),
          _Section(
            title: 'Language',
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('English')),
                ButtonSegment(value: false, label: Text('Chichewa')),
              ],
              selected: {_english},
              onSelectionChanged: (value) => setState(() => _english = value.first),
            ),
          ),
          _Section(
            title: 'Accessibility',
            child: Column(
              children: [
                SwitchListTile(
                  value: _largeText,
                  onChanged: (v) => setState(() => _largeText = v),
                  title: const Text('Large Text'),
                ),
                SwitchListTile(
                  value: _highContrast,
                  onChanged: (v) => setState(() => _highContrast = v),
                  title: const Text('High Contrast'),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Notifications',
            child: Column(
              children: [
                SwitchListTile(
                  value: _eventAlerts,
                  onChanged: (v) => setState(() => _eventAlerts = v),
                  title: const Text('Event Alerts'),
                ),
                SwitchListTile(
                  value: _tourReminders,
                  onChanged: (v) => setState(() => _tourReminders = v),
                  title: const Text('Tour Reminders'),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Quick Access',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: const Text('My Tickets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TicketWalletScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notification Center'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

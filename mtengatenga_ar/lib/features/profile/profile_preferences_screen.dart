import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/auth_state.dart';
import '../../core/ui/states/state_view.dart';
import '../../services/translation_service.dart';
import '../../theme/app_tokens.dart';
import '../events/notification_center_screen.dart';
import '../tickets/ticket_wallet_screen.dart';

class ProfilePreferencesScreen extends StatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  State<ProfilePreferencesScreen> createState() => _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState extends State<ProfilePreferencesScreen> {
  final _languageState = GetIt.instance<LanguageState>();
  final _authState = GetIt.instance<AuthStateNotifier>();
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
          // Account section
          ListenableBuilder(
            listenable: _authState,
            builder: (context, _) {
              final profile = _authState.profile;
              final user = _authState.user;
              return _Section(
                title: 'Account',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withAlpha(25),
                      child: Text(
                        (profile?.fullName.isNotEmpty == true
                                ? profile!.fullName[0]
                                : user?.email?[0] ?? '?')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.fullName ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile?.email ?? user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          ValueListenableBuilder<String>(
            valueListenable: _languageState,
            builder: (context, lang, _) => _Section(
              title: 'Language',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'en',
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\u{1F1EC}\u{1F1E7}', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 6),
                        Text('English'),
                      ],
                    ),
                  ),
                  ButtonSegment(
                    value: 'ny',
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\u{1F1F2}\u{1F1FC}', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 6),
                        Text('Chichewa'),
                      ],
                    ),
                  ),
                ],
                selected: {lang},
                onSelectionChanged: (value) =>
                    _languageState.setLanguage(value.first),
              ),
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
          // Logout
          _Section(
            title: '',
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                await GetIt.instance<AuthService>().signOut();
              },
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

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/auth_state.dart';
import '../../services/translation_service.dart';
import '../../theme/app_tokens.dart';
import '../events/notification_center_screen.dart';
import '../scan/scan_history_screen.dart';
import '../tickets/ticket_wallet_screen.dart';

class ProfilePreferencesScreen extends StatelessWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageState = GetIt.instance<LanguageState>();
    final authState = GetIt.instance<AuthStateNotifier>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Profile & Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Account
          ListenableBuilder(
            listenable: authState,
            builder: (context, _) {
              final profile = authState.profile;
              final user = authState.user;
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

          // Language
          ValueListenableBuilder<String>(
            valueListenable: languageState,
            builder: (context, lang, _) => _Section(
              title: 'Language',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'en',
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\u{1F1EC}\u{1F1E7}',
                            style: TextStyle(fontSize: 18)),
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
                        Text('\u{1F1F2}\u{1F1FC}',
                            style: TextStyle(fontSize: 18)),
                        SizedBox(width: 6),
                        Text('Chichewa'),
                      ],
                    ),
                  ),
                ],
                selected: {lang},
                onSelectionChanged: (value) =>
                    languageState.setLanguage(value.first),
              ),
            ),
          ),

          // Quick Access
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
                      MaterialPageRoute(
                          builder: (_) => const TicketWalletScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('Scan History'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ScanHistoryScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notification Center'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NotificationCenterScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Log Out
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

          // App version
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 24),
            child: Text(
              'Mtengatenga AR Museum v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
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
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../features/home/mtengatenga_home_screen.dart';
import '../../../features/profile/profile_preferences_screen.dart';
import '../../../features/saved/saved_artifacts_screen.dart';
import '../../../features/tickets/tickets_hub_screen.dart';
import '../../../theme/app_tokens.dart';
import '../../services/update_service.dart';
import '../update_prompt.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (!GetIt.instance.isRegistered<UpdateService>()) return;
    final info = await GetIt.instance<UpdateService>().checkForUpdate();
    if (info != null && mounted) {
      await UpdatePrompt.show(context, info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const MtengatengaHomeScreen(),
      const SavedArtifactsScreen(),
      const TicketsHubScreen(),
      const ProfilePreferencesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Item(
                  active: _tab == 0,
                  icon: Icons.home_filled,
                  label: 'Home',
                  onTap: () => setState(() => _tab = 0),
                ),
                _Item(
                  active: _tab == 1,
                  icon: Icons.favorite_outline,
                  label: 'Saved',
                  onTap: () => setState(() => _tab = 1),
                ),
                _Item(
                  active: _tab == 2,
                  icon: Icons.confirmation_number_outlined,
                  label: 'Tickets',
                  onTap: () => setState(() => _tab = 2),
                ),
                _Item(
                  active: _tab == 3,
                  icon: Icons.person_outline,
                  label: 'Profile',
                  onTap: () => setState(() => _tab = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

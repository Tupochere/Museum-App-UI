import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import '../ai_guide/ai_guide_screen.dart';
import 'debug_artifacts_screen.dart';
import '../events/events_screen.dart';
import '../map/indoor_navigation_screen.dart';
import '../scan/scan_screen.dart';
import '../tickets/tickets_donation_screen.dart';

class MtengatengaHomeScreen extends StatefulWidget {
  const MtengatengaHomeScreen({super.key});

  @override
  State<MtengatengaHomeScreen> createState() => _MtengatengaHomeScreenState();
}

class _MtengatengaHomeScreenState extends State<MtengatengaHomeScreen> {
  bool _isEnglish = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 6, AppSpacing.lg, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                isEnglish: _isEnglish,
                onToggle: () => setState(() => _isEnglish = !_isEnglish),
              ),
              const SizedBox(height: 18),
              Text(
                'Muli Bwanji,',
                style: AppText.greeting.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              Text(
                "Explore Malawi's\nHidden Heritage",
                style: AppText.heroTitle.copyWith(color: AppColors.textMain),
              ),
              const SizedBox(height: 22),
              _ScanCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  );
                },
              ),
              const SizedBox(height: 22),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.05,
                children: [
                  _ActionTile(
                    icon: Icons.map_outlined,
                    title: 'Explore Map',
                    subtitle: 'Find locations nearby',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const IndoorNavigationScreen()),
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.smart_toy_outlined,
                    title: 'AI Guide',
                    subtitle: 'Ask questions',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiGuideScreen()),
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Buy Ticket',
                    subtitle: 'Skip the line',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TicketsDonationScreen()),
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.event_outlined,
                    title: 'Events',
                    subtitle: "What's on now",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EventsScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DebugArtifactsScreen(),
                      ),
                    );
                  },
                  child: const Text('Test Supabase Connection'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isEnglish, required this.onToggle});

  final bool isEnglish;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.20)),
              ),
              child: const Icon(Icons.museum_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MTENGATENGA',
                  style: AppText.headerTitle.copyWith(color: AppColors.textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  'AR Museum',
                  style: AppText.headerSubtitle.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 38,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                _LangChip(active: isEnglish, label: 'EN'),
                _LangChip(active: !isEnglish, label: 'NY'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: active ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
              ),
              child: const Icon(Icons.view_in_ar, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              'Scan Artifact',
              style: AppText.cardTitle.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Point camera to discover history',
              style: AppText.cardSubtitle.copyWith(color: Colors.white.withOpacity(0.90)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.10),
              ),
              child: Icon(icon, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            Text(title, style: AppText.tileTitle.copyWith(color: AppColors.textMain)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppText.tileSubtitle.copyWith(color: AppColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

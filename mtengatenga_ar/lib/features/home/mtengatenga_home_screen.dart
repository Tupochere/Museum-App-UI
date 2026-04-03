import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/services/ticket_gate.dart';
import '../../services/translation_service.dart';
import '../../theme/app_tokens.dart';
import '../ai_guide/ai_guide_screen.dart';
import '../events/events_screen.dart';
import '../map/indoor_navigation_screen.dart';
import '../scan/scan_screen.dart';
import '../tickets/tickets_donation_screen.dart';
import '../search/search_screen.dart';

class MtengatengaHomeScreen extends StatefulWidget {
  const MtengatengaHomeScreen({super.key});

  @override
  State<MtengatengaHomeScreen> createState() => _MtengatengaHomeScreenState();
}

class _MtengatengaHomeScreenState extends State<MtengatengaHomeScreen> {
  final _languageState = GetIt.instance<LanguageState>();

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
              ValueListenableBuilder<String>(
                valueListenable: _languageState,
                builder: (context, lang, _) => _Header(
                  isEnglish: lang == 'en',
                  onToggle: () {
                    _languageState.setLanguage(lang == 'en' ? 'ny' : 'en');
                  },
                ),
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
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Search artifacts...',
                        style: AppText.tileSubtitle.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _ScanCard(
                onTap: () => TicketGate.navigate(
                  context,
                  () => const ScanScreen(),
                ),
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
                    onTap: () => TicketGate.navigate(
                      context,
                      () => const AiGuideScreen(),
                    ),
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
                _LangChip(active: isEnglish, label: 'EN', flag: '\u{1F1EC}\u{1F1E7}'),
                _LangChip(active: !isEnglish, label: 'NY', flag: '\u{1F1F2}\u{1F1FC}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.active, required this.label, required this.flag});

  final bool active;
  final String label;
  final String flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
        ],
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
              'Scan QR or identify objects',
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

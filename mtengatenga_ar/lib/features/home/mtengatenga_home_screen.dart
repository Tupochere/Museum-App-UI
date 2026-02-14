import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import '../ai_guide/ai_guide_screen.dart';
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
  int _navIndex = 0;
  bool _isEnglish = true;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 6),
            _Header(
              isEnglish: _isEnglish,
              onToggle: () => setState(() => _isEnglish = !_isEnglish),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 92),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                MaterialPageRoute(
                                  builder: (_) => const IndoorNavigationScreen(),
                                ),
                              );
                            },
                          ),
                          _ActionTile(
                            icon: Icons.smart_toy_outlined,
                            title: 'AI Guide',
                            subtitle: 'Ask questions',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AiGuideScreen(),
                                ),
                              );
                            },
                          ),
                          _ActionTile(
                            icon: Icons.confirmation_number_outlined,
                            title: 'Buy Ticket',
                            subtitle: 'Skip the line',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TicketsDonationScreen(),
                                ),
                              );
                            },
                          ),
                          _ActionTile(
                            icon: Icons.event_outlined,
                            title: 'Events',
                            subtitle: "What's on now",
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EventsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: media.padding.bottom + 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _navIndex,
        onChanged: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isEnglish,
    required this.onToggle,
  });

  final bool isEnglish;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
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
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 2),
                    color: Color(0x14000000),
                  ),
                ],
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
      ),
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
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              offset: const Offset(0, 10),
              color: AppColors.primary.withOpacity(0.25),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
                border: Border.all(color: Colors.white.withOpacity(0.20)),
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
            const SizedBox(height: 6),
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
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 3),
              color: Color(0x0F000000),
            ),
          ],
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

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, -2),
            color: Color(0x0A000000),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                active: index == 0,
                icon: Icons.home_filled,
                label: 'Home',
                onTap: () => onChanged(0),
              ),
              _NavItem(
                active: index == 1,
                icon: Icons.favorite_border,
                label: 'Saved',
                onTap: () => onChanged(1),
              ),
              _NavItem(
                active: index == 2,
                icon: Icons.confirmation_number_outlined,
                label: 'Tickets',
                onTap: () => onChanged(2),
              ),
              _NavItem(
                active: index == 3,
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: () => onChanged(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 72,
        height: double.infinity,
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

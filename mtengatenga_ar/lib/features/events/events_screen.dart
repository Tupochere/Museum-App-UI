import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _topTab = 0; // 0 upcoming, 1 past
  int _chip = 0; // 0 all, 1 exhibitions, 2 workshops, 3 live, 4 tours
  int _nav = 2; // bottom nav index: 0 Home, 1 AR Map, 2 Events, 3 Profile

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2), // cream-bg :contentReference[oaicite:1]{index=1}
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              title: 'Events & News',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 92),
                children: [
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SegmentedTop(
                      index: _topTab,
                      onChanged: (i) => setState(() => _topTab = i),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CategoryChips(
                    index: _chip,
                    onChanged: (i) => setState(() => _chip = i),
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: const [
                        _FeaturedEventCard(),
                        SizedBox(height: 12),
                        _ListEventTile(
                          dot: true,
                          icon: Icons.event,
                          iconMuted: false,
                          date: 'Oct 20 • 10:00 AM',
                          title: 'AR Exhibit: The Lake',
                          subtitle: 'Launch of our new underwater AR experience.',
                          imageUrl:
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuBlRiR1ZweR961LGxFHrMDrgMk-S7e83a_ooc10qMPS07FPVjyrrcCvYpf-IigA68LMn8iggEIULvW-P0P25lCz3Xaz-wFu5kZD8vIa3SteVotXb5sjvjC5uUV3vjz7s43F0trWqfRZiKZNpZzV7MX8yWwhiqX7q1oTjSFNjJBQBs2Lc6qLDtIXIADdqbnqmXSMnOBT9Wez6BXvNKVzU1CyrZfTmh1pxbgqlvjVDiw_JaR3WYbMO5HFD1bZwsmn4nEcwugXlevf5kJa',
                          leadingType: _TileLeading.image,
                        ),
                        _ListEventTile(
                          dot: false,
                          icon: Icons.event,
                          iconMuted: true,
                          date: 'Oct 22 • 4:00 PM',
                          title: 'Curator Talk: History',
                          subtitle: 'Join our head curator for a deep dive into history.',
                          imageUrl:
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuA6033V2aJ3pqfUlYz0daATEPZmcDCxQmzLDz90M9rUA6DqjVFW4ZngHC2rNWCaC-U7O1B_kxGgnHGcElj4_WL2Nj1-uExCD5DZpC4aW7XjK7PyLhgwgno30zPzf0_d3g8nmolGW0R5dnqsMXUKmEbI8j3BKjFiqY8MwU9UDqTDqNlYggHpar7R1brV62fTaeVNRXsK-mHP7G9_IXo_cVLRDxcewd86iM6LiiteKiphA7tYAzHxnm52PIF9TKH98GnJdWAZ4Pct1OPp',
                          leadingType: _TileLeading.image,
                        ),
                        _ListEventTile(
                          dot: true,
                          icon: Icons.newspaper,
                          iconMuted: false,
                          date: 'News • Just Now',
                          title: 'Museum Shop Reopening',
                          subtitle: 'We are excited to announce the shop is open.',
                          imageUrl: '',
                          leadingType: _TileLeading.iconBox,
                        ),
                        _ListEventTile(
                          dot: false,
                          icon: Icons.schedule,
                          iconMuted: true,
                          date: 'Nov 05 • 11:00 AM',
                          title: 'Clay Modeling Workshop',
                          subtitle: 'Hands-on session for all ages.',
                          imageUrl:
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuC-UmbfAmnrecA--7tWC18J1rDwotYU6h1aXPHIQ_lVZc9mfNjLwnbcFulAECun_MggoaXX-7QyrNzJdtf1j5PjIkPCNrPiPoamQ4VNNmS-gcBpbtm79KKZvq0Nihygmr_Ff52c8V6YMl8ykYhttedPNfBrMaCnTbUxaHCWS0dPMXXwhafbz-uCXdzcvN5HLYW2x5_p7JfXNQ95h757zuhQISYo7uonrmH23wxT6Bnst8w_Ctsc7F7vB8tVNSoYHANf1jcUKRj2DcYc',
                          leadingType: _TileLeading.image,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _EventsBottomNav(
        index: _nav,
        onChanged: (i) => setState(() => _nav = i),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7F2),
        border: Border(bottom: BorderSide(color: Color(0xFFD7CCC8))), // earth-border :contentReference[oaicite:2]{index=2}
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.arrow_back, color: AppColors.textMain),
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // balance the back button space
        ],
      ),
    );
  }
}

class _SegmentedTop extends StatelessWidget {
  const _SegmentedTop({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x4DD7CCC8), // earth-border/30 :contentReference[oaicite:3]{index=3}
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: index == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 8,
                      offset: Offset(0, 2),
                      color: Color(0x14000000),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(0),
                  child: Center(
                    child: Text(
                      'Upcoming',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain.withOpacity(index == 0 ? 1 : 0.55),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(1),
                  child: Center(
                    child: Text(
                      'Past',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain.withOpacity(index == 1 ? 1 : 0.55),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(label: 'All', active: index == 0, onTap: () => onChanged(0)),
          const SizedBox(width: 10),
          _Chip(label: 'Exhibitions', active: index == 1, onTap: () => onChanged(1)),
          const SizedBox(width: 10),
          _Chip(label: 'Workshops', active: index == 2, onTap: () => onChanged(2)),
          const SizedBox(width: 10),
          _Chip(label: 'Live', active: index == 3, onTap: () => onChanged(3)),
          const SizedBox(width: 10),
          _Chip(label: 'Tours', active: index == 4, onTap: () => onChanged(4)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFA16D5D); // terracotta in this page :contentReference[oaicite:4]{index=4}
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD7CCC8)),
          boxShadow: active
              ? const [
                  BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x14000000)),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppColors.textMain.withOpacity(0.55),
          ),
        ),
      ),
    );
  }
}

class _FeaturedEventCard extends StatelessWidget {
  const _FeaturedEventCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7CCC8)),
          boxShadow: const [
            BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x0F000000)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDpcQhgCSeZEuPVfavw2YvKqDjPkRNoZ75K_I9E5FjAUR8xh-6Pp82znRnl4PpXNCF_qHYkVQ5CAc05yeUAA-7jGdrx9DnFC2YJ53zZ9e6yATbZGKcAwNOEdrweDQ99lo91DlFRg_XBG0_hxrSln1S86RS-8Sd5e3jZ25CkCvPNKIefdba26laJKOu3TD0dTs488NUCD6hKEf8RliwsGLrLj1MxI8Ia1oA_NgdylkfGv8efT_iKXis5WnySgscJw2OdW4O_CU5zbugF',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xB3000000), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA16D5D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA16D5D),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OCT 14 • 2:00 PM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Traditional Mask Dance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Experience the Gule Wamkulu dance in the main courtyard. A vibrant display...',
                      style: TextStyle(
                        color: AppColors.textMain.withOpacity(0.70),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0x33D7CCC8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward, color: Color(0xFFA16D5D)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TileLeading { image, iconBox }

class _ListEventTile extends StatelessWidget {
  const _ListEventTile({
    required this.dot,
    required this.icon,
    required this.iconMuted,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.leadingType,
  });

  final bool dot;
  final IconData icon;
  final bool iconMuted;
  final String date;
  final String title;
  final String subtitle;
  final String imageUrl;
  final _TileLeading leadingType;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7CCC8)),
        boxShadow: const [
          BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x0F000000)),
        ],
      ),
      child: Stack(
        children: [
          if (dot)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFA16D5D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Row(
            children: [
              _leading(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: iconMuted
                              ? AppColors.textMain.withOpacity(0.35)
                              : const Color(0xFFA16D5D),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: iconMuted
                                ? AppColors.textMain.withOpacity(0.55)
                                : const Color(0xFFA16D5D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain.withOpacity(0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leading() {
    switch (leadingType) {
      case _TileLeading.iconBox:
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0x33D7CCC8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.newspaper, color: Color(0xFFA16D5D), size: 30),
        );
      case _TileLeading.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 76,
            height: 76,
            child: Image.network(imageUrl, fit: BoxFit.cover),
          ),
        );
    }
  }
}

class _EventsBottomNav extends StatelessWidget {
  const _EventsBottomNav({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFFA16D5D); // terracotta :contentReference[oaicite:5]{index=5}
    final inactive = AppColors.textMain.withOpacity(0.35);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD7CCC8))),
        boxShadow: [
          BoxShadow(blurRadius: 14, offset: Offset(0, -2), color: Color(0x0A000000)),
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
                icon: Icons.home_outlined,
                label: 'Home',
                activeColor: active,
                inactiveColor: inactive,
                onTap: () => onChanged(0),
              ),
              _NavItem(
                active: index == 1,
                icon: Icons.explore_outlined,
                label: 'AR Map',
                activeColor: active,
                inactiveColor: inactive,
                onTap: () => onChanged(1),
              ),
              _NavItem(
                active: index == 2,
                icon: Icons.calendar_month_outlined,
                label: 'Events',
                activeColor: active,
                inactiveColor: inactive,
                onTap: () => onChanged(2),
              ),
              _NavItem(
                active: index == 3,
                icon: Icons.account_circle_outlined,
                label: 'Profile',
                activeColor: active,
                inactiveColor: inactive,
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
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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
                fontSize: 10,
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

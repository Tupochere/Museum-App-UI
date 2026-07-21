import 'package:flutter/material.dart';
import '../../core/models/ui_models.dart';
import '../../theme/app_tokens.dart';
import 'event_details_screen.dart';
import 'notification_center_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _topTab = 0;
  int _chip = 0;

  static const _events = [
    UiEventItem(
      id: '1',
      title: 'Traditional Mask Dance',
      dateLabel: 'Oct 14 • 2:00 PM',
      location: 'Main Courtyard',
      description: 'Experience the Gule Wamkulu dance in a guided cultural program.',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDpcQhgCSeZEuPVfavw2YvKqDjPkRNoZ75K_I9E5FjAUR8xh-6Pp82znRnl4PpXNCF_qHYkVQ5CAc05yeUAA-7jGdrx9DnFC2YJ53zZ9e6yATbZGKcAwNOEdrweDQ99lo91DlFRg_XBG0_hxrSln1S86RS-8Sd5e3jZ25CkCvPNKIefdba26laJKOu3TD0dTs488NUCD6hKEf8RliwsGLrLj1MxI8Ia1oA_NgdylkfGv8efT_iKXis5WnySgscJw2OdW4O_CU5zbugF',
      isUnread: true,
    ),
    UiEventItem(
      id: '2',
      title: 'Clay Modeling Workshop',
      dateLabel: 'Nov 05 • 11:00 AM',
      location: 'Workshop Hall',
      description: 'Hands-on modeling workshop for all ages and school groups.',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuC-UmbfAmnrecA--7tWC18J1rDwotYU6h1aXPHIQ_lVZc9mfNjLwnbcFulAECun_MggoaXX-7QyrNzJdtf1j5PjIkPCNrPiPoamQ4VNNmS-gcBpbtm79KKZvq0Nihygmr_Ff52c8V6YMl8ykYhttedPNfBrMaCnTbUxaHCWS0dPMXXwhafbz-uCXdzcvN5HLYW2x5_p7JfXNQ95h757zuhQISYo7uonrmH23wxT6Bnst8w_Ctsc7F7vB8tVNSoYHANf1jcUKRj2DcYc',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        title: const Text('Events & News'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SegmentedTop(index: _topTab, onChanged: (i) => setState(() => _topTab = i)),
          const SizedBox(height: 12),
          _CategoryChips(index: _chip, onChanged: (i) => setState(() => _chip = i)),
          const SizedBox(height: 12),
          ..._events.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EventCard(
                item: item,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EventDetailsScreen(item: item)),
                  );
                },
              ),
            );
          }),
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
        color: const Color(0x4DD7CCC8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TopTab(label: 'Upcoming', active: index == 0, onTap: () => onChanged(0)),
          _TopTab(label: 'Past', active: index == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: active ? AppColors.textMain : AppColors.textMuted,
            ),
          ),
        ),
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
    const labels = ['All', 'Exhibitions', 'Workshops', 'Live', 'Tours'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final active = i == index;
          return InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFA16D5D) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD7CCC8)),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: labels.length,
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item, required this.onTap});
  final UiEventItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7CCC8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (item.imageUrl.isNotEmpty)
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.network(item.imageUrl, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.isUnread)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (item.isUnread) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.dateLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

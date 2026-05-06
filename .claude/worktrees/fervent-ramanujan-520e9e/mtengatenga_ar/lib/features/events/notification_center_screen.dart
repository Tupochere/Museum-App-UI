import 'package:flutter/material.dart';
import '../../core/models/ui_models.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  static const _items = [
    UiEventItem(
      id: 'n1',
      title: 'Mask Dance starts in 30 min',
      dateLabel: 'Today, 1:30 PM',
      location: 'Main Courtyard',
      description: 'Reminder for your saved event.',
      isUnread: true,
    ),
    UiEventItem(
      id: 'n2',
      title: 'Workshop seats available',
      dateLabel: 'Tomorrow, 10:00 AM',
      location: 'Workshop Hall',
      description: 'Clay modeling workshop has open slots.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Notifications')),
      body: _items.isEmpty
          ? const AppEmptyState(
              title: 'No Notifications',
              message: 'Event alerts and reminders will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
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
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.dateLabel} • ${item.location}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: _items.length,
            ),
    );
  }
}

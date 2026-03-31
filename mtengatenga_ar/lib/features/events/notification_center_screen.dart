import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/service_locator.dart';
import '../../core/ui/states/state_view.dart';
import '../../models/notification_post.dart';
import '../../services/notification_badge_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_tokens.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends State<NotificationCenterScreen> {
  final _service = ServiceLocator.instance<NotificationService>();
  final _badgeService = ServiceLocator.instance<NotificationBadgeService>();
  List<NotificationPost> _items = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _badgeService.markAllRead();
    _channel = _service.subscribeToNew((post) {
      if (mounted) {
        setState(() => _items = [post, ..._items]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New: ${post.title}')),
        );
      }
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final posts = await _service.fetchAll();
    if (mounted) setState(() { _items = posts; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const AppEmptyState(
                  title: 'No Notifications',
                  message: 'Event alerts and news will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final post = _items[index];
                      return _NotifCard(post: post);
                    },
                  ),
                ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.post});
  final NotificationPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.network(
                post.thumbnailUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty)
            const SizedBox(height: 10),
          // Badge row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: post.postType == 'event'
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  post.postType == 'event' ? 'Event' : 'News',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: post.postType == 'event'
                        ? AppColors.primary
                        : Colors.blueAccent,
                  ),
                ),
              ),
              if (post.featured) ...[
                const SizedBox(width: 6),
                const Icon(Icons.star, size: 14, color: Colors.amber),
              ],
              const Spacer(),
              Text(
                post.category,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            post.title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          // Meta: date / location
          if (post.eventDate != null)
            Text(
              '${post.eventDate}${post.eventTime != null ? ' • ${post.eventTime}' : ''}'
              '${post.location != null ? ' @ ${post.location}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          const SizedBox(height: 4),
          // Summary
          Text(
            post.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          // CTA
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text(post.ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

# Mobile App — Notifications & Events Supabase Implementation Plan

> **For Claude Code**: Read this entire document before writing a single line of code. Execute phases in order. The Supabase `notifications` table already exists — it was created by the admin dashboard implementation. Do NOT recreate it.

---

## Context & Current State

The Flutter app (`mtengatenga_ar`) has two screens that handle events and notifications:

| File | Current state |
|---|---|
| `lib/features/events/events_screen.dart` | Hardcoded `static const _events` list of `UiEventItem` |
| `lib/features/events/notification_center_screen.dart` | Hardcoded `static const _items` list — never updates |
| `lib/features/events/event_details_screen.dart` | Receives `UiEventItem` — needs no structural change, only data source |
| `lib/services/supabase_service.dart` | Only handles `artifacts` — no notifications logic |
| `lib/core/models/ui_models.dart` | Has `UiEventItem` — a UI-only model, not a Supabase model |

**Goal**: Replace all hardcoded data with live reads from the Supabase `notifications` table. Both the Events feed and the Notification Center must show real posts published by the admin dashboard.

---

## Supabase Table Reference

The `notifications` table (already created by the admin dashboard) has these columns:

```
id             uuid
post_type      text  ('event' | 'news')
title          text
summary        text
audience       text
category       text
cta_label      text
featured       boolean
status         text  ('draft' | 'sent')
event_date     date  (nullable — events only)
event_time     time  (nullable — events only)
location       text  (nullable — events only)
thumbnail_url  text  (nullable)
recipients     integer
sent_at        timestamptz  (nullable)
created_at     timestamptz
updated_at     timestamptz
```

**RLS rule already in place**: `anon` users can only SELECT rows where `status = 'sent'`. No auth is needed from the mobile app.

---

## Phase 1 — Notification Model

### 1.1 Create `lib/models/notification_post.dart`

This is a Dart model that maps directly to the Supabase `notifications` table row.

```dart
class NotificationPost {
  const NotificationPost({
    required this.id,
    required this.postType,
    required this.title,
    required this.summary,
    required this.audience,
    required this.category,
    required this.ctaLabel,
    required this.featured,
    required this.status,
    this.eventDate,
    this.eventTime,
    this.location,
    this.thumbnailUrl,
    required this.recipients,
    this.sentAt,
    required this.createdAt,
  });

  final String id;
  final String postType;       // 'event' | 'news'
  final String title;
  final String summary;
  final String audience;
  final String category;
  final String ctaLabel;
  final bool featured;
  final String status;
  final String? eventDate;
  final String? eventTime;
  final String? location;
  final String? thumbnailUrl;
  final int recipients;
  final DateTime? sentAt;
  final DateTime createdAt;

  factory NotificationPost.fromJson(Map<String, dynamic> json) {
    return NotificationPost(
      id: json['id'] as String,
      postType: json['post_type'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      audience: json['audience'] as String,
      category: json['category'] as String,
      ctaLabel: json['cta_label'] as String,
      featured: json['featured'] as bool,
      status: json['status'] as String,
      eventDate: json['event_date'] as String?,
      eventTime: json['event_time'] as String?,
      location: json['location'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      recipients: json['recipients'] as int,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to a UiEventItem for screens that still use the UI model.
  /// Used for backwards compatibility with EventDetailsScreen.
  UiEventItem toUiEventItem() {
    final datePart = eventDate ?? '';
    final timePart = eventTime ?? '';
    final dateLabel = (datePart.isNotEmpty && timePart.isNotEmpty)
        ? '$datePart • $timePart'
        : datePart.isNotEmpty
            ? datePart
            : sentAt != null
                ? '${sentAt!.day}/${sentAt!.month}/${sentAt!.year}'
                : '';

    return UiEventItem(
      id: id,
      title: title,
      dateLabel: dateLabel,
      location: location ?? '',
      description: summary,
      imageUrl: thumbnailUrl ?? '',
      isUnread: true,
    );
  }
}
```

> **Import needed** at the top: `import '../core/models/ui_models.dart';`

---

## Phase 2 — Notification Service

### 2.1 Create `lib/services/notification_service.dart`

Do **not** modify `supabase_service.dart` — it handles artifacts only. Create a new file:

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_post.dart';

class NotificationService {
  NotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetch all sent notifications ordered by newest first.
  Future<List<NotificationPost>> fetchAll() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('status', 'sent')
          .order('created_at', ascending: false);

      return (rows as List)
          .map((row) => NotificationPost.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('NotificationService.fetchAll error: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  /// Fetch only 'event' post_type rows (for the Events tab).
  Future<List<NotificationPost>> fetchEvents() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('status', 'sent')
          .eq('post_type', 'event')
          .order('created_at', ascending: false);

      return (rows as List)
          .map((row) => NotificationPost.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('NotificationService.fetchEvents error: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  /// Fetch only 'news' post_type rows (for the News tab).
  Future<List<NotificationPost>> fetchNews() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('status', 'sent')
          .eq('post_type', 'news')
          .order('created_at', ascending: false);

      return (rows as List)
          .map((row) => NotificationPost.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('NotificationService.fetchNews error: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  /// Subscribe to real-time inserts on the notifications table.
  /// Call [onNewPost] whenever a new 'sent' notification arrives.
  /// Returns the channel so the caller can unsubscribe via channel.unsubscribe().
  RealtimeChannel subscribeToNew(void Function(NotificationPost post) onNewPost) {
    return _client
        .channel('notifications-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'sent',
          ),
          callback: (payload) {
            try {
              final post = NotificationPost.fromJson(
                Map<String, dynamic>.from(payload.newRecord),
              );
              onNewPost(post);
            } catch (e) {
              debugPrint('Realtime parse error: $e');
            }
          },
        )
        .subscribe();
  }
}
```

---

## Phase 3 — Update `EventsScreen`

### 3.1 Convert to `StatefulWidget` with async loading

Replace the entire contents of `lib/features/events/events_screen.dart`. Keep the existing widget classes `_SegmentedTop`, `_TopTab`, `_CategoryChips`, and `_EventCard` — only change `_EventsScreenState`:

**Remove** the hardcoded `static const _events` list.

**Add** state variables and lifecycle methods:

```dart
// At the top of the file, add import:
import '../../models/notification_post.dart';
import '../../services/notification_service.dart';
```

**Replace `_EventsScreenState` with:**

```dart
class _EventsScreenState extends State<EventsScreen> {
  int _topTab = 0; // 0 = Upcoming (events), 1 = Past (news)
  int _chip = 0;

  final _service = NotificationService();
  List<NotificationPost> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final posts = await _service.fetchAll();
    if (mounted) {
      setState(() {
        _posts = posts;
        _loading = false;
      });
    }
  }

  List<NotificationPost> get _filtered {
    if (_topTab == 0) {
      return _posts.where((p) => p.postType == 'event').toList();
    } else {
      return _posts.where((p) => p.postType == 'news').toList();
    }
  }

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
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SegmentedTop(index: _topTab, onChanged: (i) => setState(() => _topTab = i)),
            const SizedBox(height: 12),
            _CategoryChips(index: _chip, onChanged: (i) => setState(() => _chip = i)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            else if (_filtered.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No posts yet. Check back soon.'),
                ),
              )
            else
              ..._filtered.map((post) {
                final item = post.toUiEventItem();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EventCard(
                    item: item,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EventDetailsScreen(item: item),
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
```

---

## Phase 4 — Update `NotificationCenterScreen`

This screen currently uses a hardcoded list. Replace it with a live Supabase feed that also supports **Realtime** so new notifications pop in without needing a pull-to-refresh.

**Replace the entire file** `lib/features/events/notification_center_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/ui/states/state_view.dart';
import '../../models/notification_post.dart';
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
  final _service = NotificationService();
  List<NotificationPost> _items = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
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
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.blueAccent.withOpacity(0.12),
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
```

---

## Phase 5 — pubspec.yaml Check

The `supabase_flutter: ^2.0.0` package is already in `pubspec.yaml` and the `RealtimeChannel` API is included. No new packages are needed.

However, verify there is no duplicate `supabase_flutter` entry in `pubspec.yaml` (there currently appears to be one). If duplicated, remove the second occurrence and run:

```bash
cd mtengatenga_ar
flutter pub get
```

---

## Phase 6 — Verify `main.dart` Supabase Initialization

Open `lib/main.dart` and confirm Supabase is initialized before `runApp`. It should look similar to:

```dart
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL'] ?? '',
  anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
);
```

If this initialization is missing or uses placeholder values, Claude must fix it using the `.env` file pattern already established in `mtengatenga_ar/.env.example`.

---

## Phase 7 — Verification Checklist

After all changes, verify each item:

- [ ] `lib/models/notification_post.dart` created with correct `fromJson` and `toUiEventItem()`
- [ ] `lib/services/notification_service.dart` created with `fetchAll()`, `fetchEvents()`, `fetchNews()`, and `subscribeToNew()`
- [ ] `EventsScreen` no longer has a hardcoded `_events` list — data loads from Supabase
- [ ] `EventsScreen` shows a loading spinner while fetching
- [ ] `EventsScreen` supports pull-to-refresh (`RefreshIndicator`)
- [ ] `NotificationCenterScreen` is now a `StatefulWidget` that loads from Supabase
- [ ] `NotificationCenterScreen` subscribes to Realtime and unsubscribes in `dispose()`
- [ ] Thumbnail images from `notification_thumbnails` Supabase bucket render in the card
- [ ] Featured posts show a ⭐ star badge
- [ ] Event-type posts show date, time, and location metadata
- [ ] No duplicate `supabase_flutter` entry in `pubspec.yaml`
- [ ] Running `flutter pub get` succeeds with no dependency conflicts

---

## Files Modified Summary

| File | Action |
|---|---|
| `lib/models/notification_post.dart` | **Create new** |
| `lib/services/notification_service.dart` | **Create new** |
| `lib/features/events/events_screen.dart` | Update `_EventsScreenState` — remove hardcoded list |
| `lib/features/events/notification_center_screen.dart` | Full rewrite — add Realtime + Supabase fetch |
| `mtengatenga_ar/pubspec.yaml` | Fix duplicate `supabase_flutter` entry if present |

> `lib/features/events/event_details_screen.dart` — **no changes needed**. It already accepts a `UiEventItem` which is generated by `NotificationPost.toUiEventItem()`.

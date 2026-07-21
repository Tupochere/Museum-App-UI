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

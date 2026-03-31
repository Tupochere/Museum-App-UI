import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationBadgeService extends ChangeNotifier {
  static const _lastReadKey = 'notification_last_read_at';

  DateTime? _lastReadAt;
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;
  DateTime? get lastReadAt => _lastReadAt;

  /// Load the last-read timestamp from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_lastReadKey);
    if (stored != null) {
      _lastReadAt = DateTime.tryParse(stored);
    }
  }

  /// Update the unread count based on notification timestamps.
  void updateCount(List<DateTime> notificationTimestamps) {
    if (_lastReadAt == null) {
      _unreadCount = notificationTimestamps.length;
    } else {
      _unreadCount = notificationTimestamps
          .where((t) => t.isAfter(_lastReadAt!))
          .length;
    }
    notifyListeners();
  }

  /// Mark all as read (called when user opens NotificationCenterScreen).
  Future<void> markAllRead() async {
    _lastReadAt = DateTime.now().toUtc();
    _unreadCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReadKey, _lastReadAt!.toIso8601String());
    notifyListeners();
  }

  /// Check if a specific notification is unread.
  bool isUnread(DateTime createdAt) {
    if (_lastReadAt == null) return true;
    return createdAt.isAfter(_lastReadAt!);
  }
}

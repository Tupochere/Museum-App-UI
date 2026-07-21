import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Android notification channel — must match the channelId sent by the
/// Cloud Function and declared in AndroidManifest.xml.
const _androidChannel = AndroidNotificationChannel(
  'museum_notifications',
  'Museum Notifications',
  description: 'Event alerts and news from Mtengatenga Museum',
  importance: Importance.high,
  showBadge: true,
);

class PushNotificationService {
  PushNotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize push notifications: create channel, request permission,
  /// register token, set up foreground + background handlers.
  Future<void> initialize() async {
    // 1. Create the Android notification channel (required on API 26+).
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 2. Initialize flutter_local_notifications (for foreground display).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit),
    );

    // 3. Request permission (Android 13+ POST_NOTIFICATIONS).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // 4. Register FCM token with backend.
    final token = await _messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }
    _messaging.onTokenRefresh.listen(_registerToken);

    // 5. Foreground messages — show a local heads-up notification.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  }

  Future<void> _registerToken(String token) async {
    try {
      final userId = _client.auth.currentUser?.id;
      await _client.from('device_tokens').upsert(
        {
          'fcm_token': token,
          'device_info': 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          if (userId != null) 'user_id': userId,
        },
        onConflict: 'fcm_token',
      );
      debugPrint('FCM token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Re-register the current FCM token with the authenticated user's ID.
  /// Called by AuthStateNotifier on sign-in.
  Future<void> linkCurrentUser() async {
    final token = await _messaging.getToken();
    if (token != null) await _registerToken(token);
  }

  /// Display a heads-up notification when a message arrives while the app
  /// is in the foreground (FCM won't do this automatically).
  void _showLocalNotification(RemoteMessage message) {
    debugPrint('Foreground FCM: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// Returns the initial message if the app was launched from a notification tap.
  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  /// Stream of notification taps when app is in background.
  Stream<RemoteMessage> get onMessageOpenedApp {
    return FirebaseMessaging.onMessageOpenedApp;
  }
}

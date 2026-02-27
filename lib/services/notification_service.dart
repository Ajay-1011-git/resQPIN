import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Notification service for local and push notifications.
///
/// Handles:
/// - Local notifications when family member sends SOS
/// - Officer alert notifications for new SOS in their department
/// - Storm/cyclone weather alerts for fishermen
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Initialize notification channels and FCM
  Future<void> initialize() async {
    if (_initialized) return;

    // Android notification channel setup
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Create notification channels for Android
    const sosChannel = AndroidNotificationChannel(
      'sos_alerts',
      'SOS Alerts',
      description: 'Emergency SOS alert notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const weatherChannel = AndroidNotificationChannel(
      'weather_alerts',
      'Weather Alerts',
      description: 'Storm and cyclone weather warnings',
      importance: Importance.high,
      playSound: true,
    );

    const familyChannel = AndroidNotificationChannel(
      'family_alerts',
      'Family Alerts',
      description: 'Family member emergency notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(sosChannel);
      await androidPlugin.createNotificationChannel(weatherChannel);
      await androidPlugin.createNotificationChannel(familyChannel);
    }

    // Request FCM permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    _initialized = true;
  }

  /// Show SOS alert notification (for officers)
  Future<void> showSOSNotification({
    required String title,
    required String body,
    String? sosId,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sos_alerts',
          'SOS Alerts',
          channelDescription: 'Emergency SOS alert notifications',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  /// Show family member alert
  Future<void> showFamilyNotification({
    required String memberName,
    required String sosType,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '⚠️ $memberName sent an SOS!',
      'Emergency type: $sosType — Open ResQPIN for details.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'family_alerts',
          'Family Alerts',
          channelDescription: 'Family member emergency notifications',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  /// Show weather/storm alert
  Future<void> showWeatherAlert({
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weather_alerts',
          'Weather Alerts',
          channelDescription: 'Storm and cyclone weather warnings',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Get FCM token for this device (useful for server-side targeting)
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}

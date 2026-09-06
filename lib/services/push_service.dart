import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

const _channelId = 'eflora_alerts';
const _channelName = 'E-FLORA alerts';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      debugPrint('PushService: Firebase ready');
    } catch (e) {
      debugPrint('PushService: Firebase not configured ($e)');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('PushService: background handler $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Order status and chat messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    if (Platform.isAndroid) {
      await androidPlugin?.requestNotificationsPermission();
    }
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessage);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      ApiService.registerDeviceToken(token);
    });

    _ready = true;
    await syncToken();
  }

  Future<void> syncToken() async {
    if (!_ready) {
      debugPrint('PushService: not ready, skip token sync');
      return;
    }
    try {
      final jwt = await ApiService.getToken();
      if (jwt == null || jwt.isEmpty) {
        debugPrint('PushService: skip token until login');
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('PushService: no FCM token yet');
        return;
      }
      debugPrint('PushService: got FCM token');
      await ApiService.registerDeviceToken(token);
    } catch (e) {
      debugPrint('PushService syncToken: $e');
    }
  }

  Future<void> clearToken() async {
    try {
      await ApiService.clearDeviceToken();
      if (_ready) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (e) {
      debugPrint('PushService clearToken: $e');
    }
  }

  VoidCallback? onRiderOrdersChanged;

  Future<void> _onMessage(RemoteMessage message) async {
    final type = message.data['type'] ?? '';
    if (type == 'rider_order_ready') {
      onRiderOrdersChanged?.call();
    }
    if (message.notification != null ||
        (message.data['title'] ?? '').toString().isNotEmpty) {
      await _showForeground(message);
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] ?? 'E-FLORA';
    final body = n?.body ?? message.data['body'] ?? '';
    debugPrint('PushService: FCM received in foreground title=$title body=$body data=${message.data}');
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Order status and chat messages',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
      ),
    );
  }
}

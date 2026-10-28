import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/features/bookings/screens/booking_detail_screen.dart';

/// رسائل الخلفية (التطبيق مغلق): النظام يعرض الإشعار تلقائياً، لا حاجة لعمل شيء هنا.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// إشعارات الجوال (Firebase Cloud Messaging):
/// - يسجّل رمز الجهاز في الخادم ويربطه بالحساب عند تسجيل الدخول
/// - يشترك في موضوع all_users للإشعارات العامة من لوحة الأدمن
/// - يعرض الإشعار أثناء فتح التطبيق، ويفتح الحجز عند الضغط عليه
class PushService {
  static const _topicAll = 'all_users';
  static const _channel = AndroidNotificationChannel(
    'rast_default',
    'إشعارات راست',
    description: 'تحديثات الحجوزات والعروض',
    importance: Importance.high,
  );

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String? _token;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => _openFromData(_decode(response.payload)),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await messaging.requestPermission(alert: true, badge: true, sound: true);
      // على آيفون: يعرض النظام الإشعار حتى والتطبيق مفتوح
      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromData(m.data));
      messaging.onTokenRefresh.listen((t) {
        _token = t;
        _register();
      });

      _initialized = true;

      // لا ننتظر الشبكة حتى لا يتأخر فتح التطبيق
      unawaited(_bootstrapToken(messaging));

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        // ننتظر حتى تُبنى الشاشة الأولى ثم نفتح الحجز
        Future<void>.delayed(const Duration(seconds: 2), () => _openFromData(initial.data));
      }
    } catch (e) {
      debugPrint('Push init skipped: $e');
    }
  }

  static Future<void> _bootstrapToken(FirebaseMessaging messaging) async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        // رمز APNs قد يتأخر قليلاً على آيفون
        for (var i = 0; i < 5 && await messaging.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      _token = await messaging.getToken();
      await messaging.subscribeToTopic(_topicAll);
      await _register();
    } catch (e) {
      debugPrint('Push token failed: $e');
    }
  }

  /// يُستدعى بعد تسجيل الدخول لربط الجهاز بالحساب.
  static Future<void> syncToken() async {
    if (!_initialized) return;
    if (_token == null) {
      try {
        _token = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }
    await _register();
  }

  /// يُستدعى قبل تسجيل الخروج: يُفصل الجهاز عن الحساب (يبقى على الإشعارات العامة).
  static Future<void> detach() async {
    final token = _token;
    if (token == null) return;
    try {
      await ApiClient().post('device-tokens/remove', body: {'token': token});
    } catch (_) {}
  }

  static Future<void> _register() async {
    final token = _token;
    if (token == null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      await ApiClient().post('device-tokens', body: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app_version': '${info.version}+${info.buildNumber}',
        'locale': PlatformDispatcher.instance.locale.languageCode,
      });
    } catch (e) {
      debugPrint('Push register failed: $e');
    }
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null || kIsWeb || !Platform.isAndroid) return; // آيفون يعرضه النظام
    await _local.show(
      id: message.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF5B469D),
          styleInformation: BigTextStyleInformation(n.body ?? ''),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Map<String, dynamic> _decode(String? payload) {
    if (payload == null || payload.isEmpty) return {};
    try {
      final v = jsonDecode(payload);
      return v is Map<String, dynamic> ? v : {};
    } catch (_) {
      return {};
    }
  }

  /// فتح الحجز المرتبط بالإشعار (إن وُجد)
  static Future<void> _openFromData(Map<String, dynamic> data) async {
    AnalyticsService.logEvent('push_open', {'push_type': data['type']});
    final id = int.tryParse(data['booking_id']?.toString() ?? '');
    final nav = navigatorKey.currentState;
    if (id == null || nav == null) return;
    try {
      final booking = await Api.bookings.getBooking(id);
      // تذكير التقييم أو «اكتمل حجزك»: نفتح نافذة التقييم مباشرة
      final openReview = data['type'] == 'review_reminder' || data['type'] == 'completed';
      nav.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking, openReview: openReview)));
    } catch (_) {}
  }
}

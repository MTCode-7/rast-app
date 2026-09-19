import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rast/core/services/snap_pixel_service.dart';

/// Centralized product and acquisition event tracking.
class AnalyticsService {
  static const _snapPixelIdKey = 'snap_pixel_id';
  static final FirebaseAnalytics _firebase = FirebaseAnalytics.instance;
  static final FirebaseRemoteConfig _remoteConfig =
      FirebaseRemoteConfig.instance;
  static const MethodChannel _snapChannel = MethodChannel(
    'com.rast.labs/snap_app_events',
  );

  static Future<void> init() async {
    var snapPixelId = '';
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await _remoteConfig.setDefaults(const {_snapPixelIdKey: ''});
      await _remoteConfig.fetchAndActivate();
      snapPixelId = _remoteConfig.getString(_snapPixelIdKey).trim();
    } catch (_) {}
    await SnapPixelService.init(snapPixelId);
    try {
      await _firebase.setAnalyticsCollectionEnabled(true);
      await logEvent('app_open');
    } catch (_) {
      // Firebase is unavailable until the platform configuration is added.
    }
  }

  static Future<void> setUserId(String? userId) async {
    try {
      await _firebase.setUserId(id: userId);
    } catch (_) {}
    await _sendToSnap('set_user_id', {'user_id': userId});
  }

  static Future<void> logLogin({String method = 'phone'}) async {
    await logEvent('login', {'method': method});
  }

  static Future<void> logSignUp({String method = 'phone'}) async {
    await logEvent('sign_up', {'method': method});
  }

  static Future<void> logCheckoutStarted({
    required int itemCount,
    double? value,
    String currency = 'SAR',
  }) async {
    await logEvent('begin_checkout', {
      'item_count': itemCount,
      if (value != null) 'value': value,
      'currency': currency,
    });
  }

  static Future<void> logPurchase({
    required String transactionId,
    double? value,
    String currency = 'SAR',
    int? itemCount,
  }) async {
    await logEvent('purchase', {
      'transaction_id': transactionId,
      if (value != null) 'value': value,
      'currency': currency,
      if (itemCount != null) 'item_count': itemCount,
    });
  }

  static Future<void> logSubscription({
    required String subscriptionId,
    double? value,
    String currency = 'SAR',
  }) async {
    await logEvent('subscribe', {
      'subscription_id': subscriptionId,
      if (value != null) 'value': value,
      'currency': currency,
    });
  }

  static Future<void> logEvent(
    String name, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) async {
    final sanitized = <String, Object>{
      for (final entry in parameters.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    try {
      await _firebase.logEvent(name: name, parameters: sanitized);
    } catch (_) {}
    await SnapPixelService.track(name, sanitized);
    await _sendToSnap(name, sanitized);
  }

  static Future<void> _sendToSnap(
    String name,
    Map<String, Object?> parameters,
  ) async {
    if (kIsWeb) return;
    try {
      await _snapChannel.invokeMethod<void>('track_event', {
        'name': name,
        'parameters': parameters,
      });
    } on MissingPluginException {
      // The native Snap SDK is optional until its App ID is configured.
    } catch (_) {}
  }
}

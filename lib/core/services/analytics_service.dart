import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rast/core/services/snap_pixel_service.dart';

/// تتبع الأحداث في Firebase / Google Analytics 4 (وتمريرها لقناة Snap الاختيارية).
///
/// نستخدم أحداث GA4 القياسية للتجارة الإلكترونية (view_item, add_to_cart, purchase...)
/// مع قائمة items حتى تظهر في تقارير «تحقيق الدخل» وتُستورد كتحويلات في Google Ads.
class AnalyticsService {
  static const _snapPixelIdKey = 'snap_pixel_id';
  static const currency = 'SAR';
  static final FirebaseAnalytics _firebase = FirebaseAnalytics.instance;
  static final FirebaseRemoteConfig _remoteConfig =
      FirebaseRemoteConfig.instance;
  static const MethodChannel _snapChannel = MethodChannel(
    'com.rast.labs/snap_app_events',
  );

  static String? _lastScreen;

  static Future<void> init() async {
    try {
      await _firebase.setAnalyticsCollectionEnabled(true);
      await _firebase.logAppOpen();
    } catch (e) {
      debugPrint('Analytics init failed: $e');
    }
    await _sendToSnap('app_open', const {});

    // إعدادات Snap من Remote Config لا تؤخر فتح التطبيق
    _initSnapPixel();
  }

  static Future<void> _initSnapPixel() async {
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
  }

  // ===================== المستخدم =====================

  static Future<void> setUserId(String? userId) async {
    await _safe(() => _firebase.setUserId(id: userId));
    await _sendToSnap('set_user_id', {'user_id': userId});
  }

  static Future<void> setLanguage(String lang) =>
      _safe(() => _firebase.setUserProperty(name: 'app_language', value: lang));

  static Future<void> logLogin({String method = 'phone'}) async {
    await _safe(() => _firebase.logLogin(loginMethod: method));
    await _sendToSnap('login', {'method': method});
  }

  static Future<void> logSignUp({String method = 'phone'}) async {
    await _safe(() => _firebase.logSignUp(signUpMethod: method));
    await _sendToSnap('sign_up', {'method': method});
  }

  static Future<void> logLogout() => logEvent('logout');

  // ===================== الشاشات =====================

  /// تُستدعى من initState لكل شاشة (الشاشات تُفتح بدون أسماء مسارات).
  static Future<void> logScreen(String name) async {
    if (_lastScreen == name) return;
    _lastScreen = name;
    await _safe(() => _firebase.logScreenView(screenName: name, screenClass: name));
  }

  // ===================== التصفح =====================

  /// عنصر GA4 من بيانات تحليل/باقة/مختبر
  static AnalyticsEventItem item({
    required Object? id,
    required String? name,
    String category = 'test',
    double? price,
    String? lab,
    String? variant,
    int quantity = 1,
  }) {
    return AnalyticsEventItem(
      itemId: (id ?? name ?? 'unknown').toString(),
      itemName: (name == null || name.trim().isEmpty) ? 'unknown' : name.trim(),
      itemCategory: category,
      itemBrand: lab,
      itemVariant: variant,
      price: price,
      quantity: quantity,
    );
  }

  /// عنصر من خريطة بيانات API (تحليل، باقة، مختبر) — يجرّب أسماء الحقول الشائعة
  static AnalyticsEventItem itemFromMap(Map map, {String category = 'test', String? lab}) {
    double? price;
    for (final k in ['final_price', 'price', 'in_clinic_price', 'min_price', 'price_from']) {
      final v = map[k];
      final p = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
      if (p != null && p > 0) {
        price = p;
        break;
      }
    }
    final service = map['service'] is Map ? map['service'] as Map : const {};
    return item(
      id: map['id'] ?? map['provider_service_id'] ?? service['id'],
      name: (map['name_ar'] ?? map['business_name_ar'] ?? service['name_ar'] ?? map['name'] ?? map['name_en'])?.toString(),
      category: category,
      price: price,
      lab: lab,
    );
  }

  static Future<void> logViewItem(AnalyticsEventItem item) async {
    await _safe(() => _firebase.logViewItem(
          currency: currency,
          value: item.price?.toDouble(),
          items: [item],
        ));
    await _sendToSnap('view_item', {'item_id': item.itemId, 'item_name': item.itemName, 'value': item.price});
  }

  static Future<void> logSelectItem(AnalyticsEventItem item, {String list = 'list'}) =>
      _safe(() => _firebase.logSelectItem(itemListName: list, items: [item]));

  static Future<void> logSearch(String term, {String area = 'general'}) async {
    final t = term.trim();
    if (t.isEmpty) return;
    await _safe(() => _firebase.logSearch(searchTerm: t, parameters: {'search_area': area}));
    await _sendToSnap('search', {'search_term': t});
  }

  static Future<void> logAddToWishlist(AnalyticsEventItem item) async {
    await _safe(() => _firebase.logAddToWishlist(currency: currency, value: item.price?.toDouble(), items: [item]));
    await _sendToSnap('add_to_wishlist', {'item_id': item.itemId});
  }

  // ===================== السلة والشراء =====================

  static Future<void> logAddToCart(AnalyticsEventItem item) async {
    await _safe(() => _firebase.logAddToCart(currency: currency, value: item.price?.toDouble(), items: [item]));
    await _sendToSnap('add_to_cart', {'item_id': item.itemId, 'value': item.price, 'currency': currency});
  }

  static Future<void> logRemoveFromCart(AnalyticsEventItem item) =>
      _safe(() => _firebase.logRemoveFromCart(currency: currency, value: item.price?.toDouble(), items: [item]));

  static Future<void> logViewCart({required double value, required List<AnalyticsEventItem> items}) =>
      _safe(() => _firebase.logViewCart(currency: currency, value: value, items: items));

  static Future<void> logCheckoutStarted({
    required int itemCount,
    double? value,
    List<AnalyticsEventItem>? items,
  }) async {
    await _safe(() => _firebase.logBeginCheckout(
          currency: currency,
          value: value,
          items: items,
          parameters: {'item_count': itemCount},
        ));
    await _sendToSnap('begin_checkout', {'item_count': itemCount, 'value': value, 'currency': currency});
  }

  static Future<void> logPurchase({
    required String transactionId,
    double? value,
    int? itemCount,
    List<AnalyticsEventItem>? items,
  }) async {
    await _safe(() => _firebase.logPurchase(
          transactionId: transactionId,
          currency: currency,
          value: value,
          items: items,
          parameters: {if (itemCount != null) 'item_count': itemCount},
        ));
    await _sendToSnap('purchase', {
      'transaction_id': transactionId,
      'value': value,
      'currency': currency,
      'item_count': itemCount,
    });
  }

  static Future<void> logSubscription({
    required String subscriptionId,
    double? value,
  }) =>
      logEvent('subscribe', {'subscription_id': subscriptionId, 'value': value, 'currency': currency});

  // ===================== أحداث مخصصة =====================

  /// أسماء الأحداث المخصصة: حروف إنجليزية صغيرة و _ فقط (حد Firebase 40 حرفاً)
  static Future<void> logEvent(
    String name, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) async {
    final sanitized = _sanitize(parameters);
    await _safe(() => _firebase.logEvent(name: name, parameters: sanitized));
    await SnapPixelService.track(name, sanitized);
    await _sendToSnap(name, sanitized);
  }

  /// Firebase يقبل نصوصاً وأرقاماً فقط كقيم (القيم المنطقية تُرفض وتُسقط الحدث)
  static Map<String, Object> _sanitize(Map<String, Object?> parameters) {
    final out = <String, Object>{};
    parameters.forEach((key, value) {
      if (value == null) return;
      if (value is num || value is String) {
        out[key] = value is String && value.length > 100 ? value.substring(0, 100) : value;
      } else if (value is bool) {
        out[key] = value ? 1 : 0;
      } else {
        out[key] = value.toString();
      }
    });
    return out;
  }

  static Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('Analytics event failed: $e');
    }
  }

  static Future<void> _sendToSnap(
    String name,
    Map<String, Object?> parameters,
  ) async {
    if (kIsWeb) return;
    try {
      await _snapChannel.invokeMethod<void>('track_event', {
        'name': name,
        'parameters': _sanitize(parameters),
      });
    } on MissingPluginException {
      // The native Snap SDK is optional until its App ID is configured.
    } catch (_) {}
  }
}

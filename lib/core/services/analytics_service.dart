import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/services/snap_pixel_service.dart';
import 'package:tiktok_events_sdk/tiktok_events_sdk.dart';

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
    // TikTok App Events SDK (التثبيت وفتح التطبيق تلقائياً، وبقية الأحداث من هنا)
    _initTikTok();
  }

  // ===================== TikTok =====================

  // من TikTok Events Manager ← مصادر بيانات التطبيق (Android و iOS)
  static const _ttAndroidAppId = 'com.rast.labs';
  static const _ttAndroidTikTokId = '7683930319421997074';
  static const _ttAndroidSecret = 'TTv1H1djqRBYUvGgYnGsBBOXZYcJpABv';
  static const _ttIosAppId = '6760505768';
  static const _ttIosTikTokId = '7683936541463920648';
  // سر تطبيق آيفون من صفحة تطبيق iOS في TikTok (إن اختلف عن أندرويد)
  static const String? _ttIosSecret = null;

  static bool _ttReady = false;

  static Future<void> _initTikTok() async {
    if (kIsWeb) return;
    try {
      await TikTokEventsSdk.initSdk(
        androidAppId: _ttAndroidAppId,
        tikTokAndroidId: _ttAndroidTikTokId,
        iosAppId: _ttIosAppId,
        tiktokIosId: _ttIosTikTokId,
        isDebugMode: kDebugMode,
        logLevel: kDebugMode ? TikTokLogLevel.debug : TikTokLogLevel.none,
        androidOptions: const TikTokAndroidOptions(appSecret: _ttAndroidSecret),
        iosOptions: const TikTokIosOptions(
          accessToken: _ttIosSecret,
          // نافذة إذن التتبع في آيفون بعد ثوانٍ من الفتح (مطلوبة لقياس الإعلانات)
          displayAtt: true,
          attUserAuthorizationDelaySeconds: 3,
        ),
      );
      _ttReady = true;
      // المستخدم المسجّل مسبقاً (فتح التطبيق وهو داخل حسابه): نربطه بعد جاهزية الـ SDK
      final pending = _pendingIdentity;
      if (pending != null) {
        _pendingIdentity = null;
        await setUserId(pending.$1, email: pending.$2, phone: pending.$3);
      }
    } catch (e) {
      debugPrint('TikTok init failed: $e');
    }
  }

  static (String, String?, String?)? _pendingIdentity;

  /// يرسل حدثاً لتيك توك. أحداث المحتوى (عرض/سلة/دفع/شراء) بنوعها القياسي،
  /// والقيمة بالريال، ومعرّف المحتوى رقم فقط (بلا أسماء تحاليل: بيانات صحية).
  static Future<void> _sendToTikTok(
    String eventName, {
    TTEventType type = TTEventType.none,
    double? value,
    String? contentId,
    String? contentType,
    int? quantity,
    String? eventId,
  }) async {
    if (!_ttReady) return;
    try {
      await TikTokEventsSdk.logEvent(
        event: TikTokEvent(
          eventName: eventName,
          eventType: type,
          eventId: eventId,
          properties: EventProperties(
            value: value,
            currency: value != null ? CurrencyCode.SAR : null,
            contentId: contentId,
            contentType: contentType,
            quantity: quantity,
          ),
        ),
      );
    } catch (e) {
      debugPrint('TikTok event failed: $e');
    }
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

  static Future<void> setUserId(String? userId, {String? email, String? phone}) async {
    await _safe(() => _firebase.setUserId(id: userId));
    await _sendToSnap('set_user_id', {'user_id': userId});
    // تيك توك: ربط الأحداث بالحساب لتحسين المطابقة (البريد والجوال تُشفَّر داخل الـ SDK)
    if (!_ttReady && userId != null) {
      _pendingIdentity = (userId, email, phone);
    }
    if (_ttReady) {
      try {
        if (userId == null) {
          await TikTokEventsSdk.logout();
        } else {
          await TikTokEventsSdk.identify(
            identifier: TikTokIdentifier(
              externalId: userId,
              email: (email ?? '').trim().isEmpty ? null : email!.trim().toLowerCase(),
              phoneNumber: _e164(phone),
            ),
          );
        }
      } catch (e) {
        debugPrint('TikTok identify failed: $e');
      }
    }
  }

  /// 05xxxxxxxx → +9665xxxxxxxx (الصيغة الدولية المطلوبة للمطابقة)
  static String? _e164(String? phone) {
    var d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return null;
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('05')) d = '966${d.substring(1)}';
    if (d.length == 9 && d.startsWith('5')) d = '966$d';
    return d.length >= 11 ? '+$d' : null;
  }

  static Future<void> setLanguage(String lang) =>
      _safe(() => _firebase.setUserProperty(name: 'app_language', value: lang));

  static Future<void> logLogin({String method = 'phone'}) async {
    await _safe(() => _firebase.logLogin(loginMethod: method));
    await _sendToSnap('login', {'method': method});
    await _sendToTikTok('Login');
  }

  static Future<void> logSignUp({String method = 'phone'}) async {
    await _safe(() => _firebase.logSignUp(signUpMethod: method));
    await _sendToSnap('sign_up', {'method': method});
    await _sendToTikTok('Registration');
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

  /// عنصر GA4 من بيانات تحليل/باقة/مختبر.
  /// اسم التحليل أو الباقة لا يُرسل (بيانات صحية تمنعها سياسات Google/Snap/Meta):
  /// نرسل التصنيف + المعرّف مثل الموقع، ويبقى اسم المختبر فقط.
  static AnalyticsEventItem item({
    required Object? id,
    required String? name,
    String category = 'test',
    double? price,
    String? lab,
    String? variant,
    int quantity = 1,
  }) {
    final itemId = (id ?? 'unknown').toString();
    final labName = (name == null || name.trim().isEmpty) ? 'unknown' : name.trim();
    return AnalyticsEventItem(
      itemId: itemId,
      itemName: category == 'lab' ? labName : '$category-$itemId',
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
    await _sendToSnap('view_item', {'item_id': item.itemId, 'value': item.price, 'currency': currency});
    await _sendToTikTok('ViewContent',
        type: TTEventType.viewContent,
        value: item.price?.toDouble(),
        contentId: item.itemId,
        contentType: 'product');
  }

  static Future<void> logSelectItem(AnalyticsEventItem item, {String list = 'list'}) =>
      _safe(() => _firebase.logSelectItem(itemListName: list, items: [item]));

  static Future<void> logSearch(String term, {String area = 'general'}) async {
    final t = term.trim();
    if (t.isEmpty) return;
    await _safe(() => _firebase.logSearch(searchTerm: t, parameters: {'search_area': area}));
    // نص البحث يبقى في Firebase للتقارير فقط، ولا يُرسل لمنصة إعلانية (قد يكون اسم تحليل)
    await _sendToSnap('search', {'search_area': area});
    await _sendToTikTok('Search');
  }

  static Future<void> logAddToWishlist(AnalyticsEventItem item) async {
    await _safe(() => _firebase.logAddToWishlist(currency: currency, value: item.price?.toDouble(), items: [item]));
    await _sendToSnap('add_to_wishlist', {'item_id': item.itemId});
    await _sendToTikTok('AddToWishlist',
        type: TTEventType.addToWishlist,
        value: item.price?.toDouble(),
        contentId: item.itemId,
        contentType: 'product');
  }

  // ===================== السلة والشراء =====================

  static Future<void> logAddToCart(AnalyticsEventItem item) async {
    await _safe(() => _firebase.logAddToCart(currency: currency, value: item.price?.toDouble(), items: [item]));
    await _sendToSnap('add_to_cart', {'item_id': item.itemId, 'value': item.price, 'currency': currency});
    await _sendToTikTok('AddToCart',
        type: TTEventType.addToCart,
        value: item.price?.toDouble(),
        contentId: item.itemId,
        contentType: 'product',
        quantity: 1);
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
    await _sendToTikTok('Checkout',
        type: TTEventType.checkout,
        value: value,
        contentType: 'product',
        quantity: itemCount);
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
    // الشراء (حدث التحسين لحملات التطبيق). معرّف الحدث = رقم العملية لمنع التكرار
    await _sendToTikTok('Purchase',
        type: TTEventType.purchase,
        value: value,
        contentType: 'product',
        quantity: itemCount ?? 1,
        eventId: transactionId);
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

  /// أحداث سناب التي يمرّرها الخادم (Conversions API). الشراء يرسله الخادم بعد الدفع الفعلي.
  static const _snapServerEvents = {
    'view_item', 'search', 'add_to_wishlist', 'add_to_cart', 'begin_checkout', 'sign_up', 'login',
  };

  static Future<void> _sendToSnap(
    String name,
    Map<String, Object?> parameters,
  ) async {
    if (kIsWeb) return;
    if (_snapServerEvents.contains(name)) {
      // التطبيق بلا SDK سناب: الخادم يرسل الحدث بمعلومات الجهاز (لا أسماء تحاليل ولا نص بحث)
      final value = parameters['value'];
      final items = parameters['item_count'];
      unawaited(ApiClient().post('track/snap', body: {
        'event': name,
        if (value is num) 'value': value,
        if (items is num) 'num_items': items.toInt(),
      }).then((_) {}, onError: (_) {}));
      return;
    }
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

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/features/auth/services/auth_service.dart';

/// حالة السلة — عداد العناصر وتحديث بعد الإضافة/الحذف.
class CartService extends ChangeNotifier {
  Map<String, dynamic>? _cartData;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get cartData => _cartData;
  bool get isLoading => _loading;
  String? get error => _error;

  List<dynamic> get items {
    final list = _cartData?['items'];
    return list is List ? List.from(list) : [];
  }

  Map<String, dynamic>? get summary {
    final s = _cartData?['summary'];
    return s is Map<String, dynamic> ? s : null;
  }

  Map<String, dynamic>? get provider {
    final p = _cartData?['provider'];
    return p is Map<String, dynamic> ? p : null;
  }

  int get itemsCount {
    final fromSummary = summary?['items_count'];
    if (fromSummary is int) return fromSummary;
    if (fromSummary != null) {
      final parsed = int.tryParse(fromSummary.toString());
      if (parsed != null) return parsed;
    }
    return items.length;
  }

  double get totalAmount {
    final v = summary?['total_amount'];
    if (v is num) return v.toDouble();
    if (v != null) return double.tryParse(v.toString()) ?? 0;
    return 0;
  }

  bool get hasItems => itemsCount > 0;

  void clearLocal() {
    _cartData = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!AuthService.isLoggedIn) {
      clearLocal();
      return;
    }
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final data = await Api.cart.getCart();
      _cartData = data;
      _error = null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        clearLocal();
        return;
      }
      _error = e.message;
    } catch (_) {
      _error = 'تعذر تحميل السلة';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void applyCartResponse(Map<String, dynamic> data) {
    _cartData = data;
    _error = null;
    notifyListeners();
  }

  /// عنصر تحليلات من سطر في السلة
  AnalyticsEventItem analyticsItem(Map line) {
    final service = line['service'] is Map ? line['service'] as Map : const {};
    final total = line['line_total'];
    return AnalyticsService.item(
      id: line['provider_service_id'] ?? service['id'],
      name: (service['name_ar'] ?? service['name_en'])?.toString(),
      price: total is num ? total.toDouble() : double.tryParse('$total'),
      lab: provider?['business_name_ar']?.toString(),
      variant: line['service_type']?.toString(),
    );
  }

  List<AnalyticsEventItem> get analyticsItems =>
      items.whereType<Map>().map(analyticsItem).toList();

  Future<bool> addItem(Map<String, dynamic> body) async {
    if (!AuthService.isLoggedIn) return false;
    _loading = true;
    notifyListeners();
    try {
      final data = await Api.cart.addItem(body);
      applyCartResponse(data);
      final added = items.whereType<Map>().lastWhere(
            (l) => '${l['provider_service_id']}' == '${body['provider_service_id']}',
            orElse: () => const {},
          );
      if (added.isNotEmpty) AnalyticsService.logAddToCart(analyticsItem(added));
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> removeItem(int itemId) async {
    final removed = items.whereType<Map>().firstWhere(
          (l) => '${l['id']}' == '$itemId',
          orElse: () => const {},
        );
    final removedItem = removed.isNotEmpty ? analyticsItem(removed) : null;
    _loading = true;
    notifyListeners();
    try {
      final data = await Api.cart.removeItem(itemId);
      applyCartResponse(data);
      if (removedItem != null) AnalyticsService.logRemoveFromCart(removedItem);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    _loading = true;
    notifyListeners();
    try {
      await Api.cart.clearCart();
      _cartData = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

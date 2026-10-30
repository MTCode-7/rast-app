import 'package:flutter/material.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/widgets/rast_kit.dart';

/// إعدادات نقاط الولاء من /api/config (تُجلب مرة واحدة وتُخزّن) لعرض «اربح X نقطة» قبل الحجز.
class LoyaltyConfig {
  LoyaltyConfig._();

  static final ValueNotifier<Map<String, dynamic>?> data = ValueNotifier(null);
  static Future<void>? _loading;

  static Future<void> ensureLoaded() {
    if (data.value != null) return Future.value();
    return _loading ??= () async {
      try {
        final cfg = await Api.home.getConfig();
        final l = cfg['loyalty'];
        data.value = l is Map ? Map<String, dynamic>.from(l) : <String, dynamic>{'enabled': false};
      } catch (_) {
        _loading = null; // نعيد المحاولة لاحقاً
      }
    }();
  }

  static bool get enabled => data.value?['enabled'] == true;
  static double get pointsPerSar => numOf(data.value?['points_per_sar']) ?? 1;
  static double get pointValueSar => numOf(data.value?['point_value_sar']) ?? 0.05;
  static int get referralBonus => (numOf(data.value?['referral_bonus']) ?? 0).toInt();
  static int get signupBonus => (numOf(data.value?['signup_bonus']) ?? 0).toInt();

  /// النقاط المتوقعة لمبلغ (بدون مضاعف المستوى — تقدير أدنى)
  static int pointsFor(num? amount) {
    if (!enabled || amount == null || amount <= 0) return 0;
    return (amount * pointsPerSar).floor();
  }
}

/// شارة صغيرة «اربح X نقطة» تظهر فقط عند تفعيل الولاء.
class EarnPointsBadge extends StatefulWidget {
  const EarnPointsBadge({super.key, required this.amount, required this.lang, this.dense = true, this.onDark = false});

  final num? amount;
  final String lang;
  final bool dense;
  final bool onDark;

  @override
  State<EarnPointsBadge> createState() => _EarnPointsBadgeState();
}

class _EarnPointsBadgeState extends State<EarnPointsBadge> {
  @override
  void initState() {
    super.initState();
    LoyaltyConfig.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: LoyaltyConfig.data,
      builder: (context, _, __) {
        final pts = LoyaltyConfig.pointsFor(widget.amount);
        if (pts <= 0) return const SizedBox.shrink();
        final label = L(widget.lang, 'اربح $pts نقطة', 'Earn $pts pts');
        if (widget.onDark) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, size: 13, color: RastTokens.gold),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        }
        return RastPill(label: label, icon: Icons.stars_rounded, color: const Color(0xFFB7791F), dense: widget.dense);
      },
    );
  }
}

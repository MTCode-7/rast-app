import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// حركة «طيران العنصر إلى السلة»:
/// تنطلق كرة صغيرة تحمل صورة التحليل من زر الإضافة، وتقفز في قوس حتى أيقونة السلة الظاهرة،
/// وعند وصولها فقط يزيد عداد السلة وتهتز الأيقونة.
class FlyToCart {
  FlyToCart._();

  /// عدد العناصر التي ما زالت «في الطريق»: أيقونة السلة تطرحها من العداد حتى تهبط.
  static final ValueNotifier<int> pending = ValueNotifier<int>(0);

  /// يزيد مع كل هبوط: أيقونات السلة تستمع له لتقفز.
  static final ValueNotifier<int> landed = ValueNotifier<int>(0);

  static final List<GlobalKey> _targets = [];

  static void registerTarget(GlobalKey key) {
    _targets.remove(key);
    _targets.add(key);
  }

  static void unregisterTarget(GlobalKey key) => _targets.remove(key);

  /// أحدث أيقونة سلة ظاهرة في الشاشة الحالية (أو في طبقة عائمة مثل إشعار الإضافة).
  /// الأولوية لأيقونة السلة داخل الصفحة نفسها، ثم أيقونة الإشعار العائم.
  static Rect? _visibleTargetRect() =>
      _findTarget(inRoute: true) ?? _findTarget(inRoute: false);

  static Rect? _findTarget({required bool inRoute}) {
    for (final key in _targets.reversed) {
      final ctx = key.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      final route = ModalRoute.of(ctx);
      if ((route != null) != inRoute) continue;
      if (route != null && !route.isCurrent) continue;
      if (!TickerMode.of(ctx)) continue; // تبويب غير ظاهر في IndexedStack
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final origin = box.localToGlobal(Offset.zero);
      final rect = origin & box.size;
      final screen = MediaQuery.sizeOf(ctx);
      if (rect.right < 0 || rect.bottom < 0 || rect.left > screen.width || rect.top > screen.height) continue;
      return rect;
    }
    return null;
  }

  /// موضع عنصر على الشاشة (لحفظ موضع زر الإضافة قبل إغلاق شاشته).
  static Rect? rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// يُستدعى بعد نجاح الإضافة. [delay] يترك وقتاً لانتهاء إغلاق الشاشة قبل حساب الهدف.
  static Future<void> run({
    required OverlayState overlay,
    required Rect? from,
    String? imageUrl,
    IconData icon = Icons.biotech_rounded,
    Duration delay = const Duration(milliseconds: 380),
  }) async {
    pending.value++;
    var landedOnce = false;
    void land() {
      if (landedOnce) return;
      landedOnce = true;
      pending.value = math.max(0, pending.value - 1);
      landed.value++;
      HapticFeedback.mediumImpact();
    }

    try {
      HapticFeedback.lightImpact();
      await Future<void>.delayed(delay);
      if (!overlay.mounted) return;
      final screen = MediaQuery.sizeOf(overlay.context);
      final target = _visibleTargetRect();
      final start = from?.center ?? Offset(screen.width / 2, screen.height - 140);
      final end = target?.center ?? Offset(screen.width - 40, 60);

      final completer = Completer<void>();
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _FlightLayer(
          start: start,
          end: end,
          imageUrl: imageUrl,
          icon: icon,
          onLand: land,
          onDone: () {
            entry.remove();
            if (!completer.isCompleted) completer.complete();
          },
        ),
      );
      overlay.insert(entry);
      await completer.future.timeout(const Duration(seconds: 3), onTimeout: () {});
    } finally {
      land(); // لا يبقى العداد ناقصاً مهما حدث
    }
  }
}

class _FlightLayer extends StatefulWidget {
  const _FlightLayer({
    required this.start,
    required this.end,
    required this.imageUrl,
    required this.icon,
    required this.onLand,
    required this.onDone,
  });

  final Offset start;
  final Offset end;
  final String? imageUrl;
  final IconData icon;
  final VoidCallback onLand;
  final VoidCallback onDone;

  @override
  State<_FlightLayer> createState() => _FlightLayerState();
}

class _FlightLayerState extends State<_FlightLayer> with SingleTickerProviderStateMixin {
  // 0..0.18 ظهور ونبضة، 0.18..0.82 طيران في قوس، 0.82..1 تناثر عند الهبوط
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_landed && _c.value >= 0.82) {
        _landed = true;
        widget.onLand();
      }
    });
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset _bezier(double t) {
    final s = widget.start;
    final e = widget.end;
    // نقطة التحكم أعلى من الطرفين لتصنع قفزة
    final control = Offset((s.dx + e.dx) / 2, math.min(s.dy, e.dy) - 160);
    final u = 1 - t;
    return s * (u * u) + control * (2 * u * t) + e * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final children = <Widget>[];

          if (v < 0.86) {
            final pop = Curves.elasticOut.transform((v / 0.18).clamp(0.0, 1.0));
            final flightT = Curves.easeInOutCubic.transform(((v - 0.18) / 0.64).clamp(0.0, 1.0));
            final pos = _bezier(flightT);
            final size = 58.0 * (v < 0.18 ? (0.4 + 0.6 * pop) : (1 - 0.68 * flightT));
            final angle = flightT * math.pi * 0.9;
            final opacity = v > 0.8 ? ((0.86 - v) / 0.06).clamp(0.0, 1.0) : 1.0;

            // ذيل خفيف خلف الكرة
            for (var i = 1; i <= 3; i++) {
              final tt = (flightT - i * 0.05).clamp(0.0, 1.0);
              if (flightT <= 0 || tt <= 0) continue;
              final p = _bezier(tt);
              final r = size * (0.32 - i * 0.07);
              children.add(Positioned(
                left: p.dx - r,
                top: p.dy - r,
                child: Opacity(
                  opacity: opacity * (0.35 - i * 0.08),
                  child: Container(
                    width: r * 2,
                    height: r * 2,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RastUi.brandGradient),
                  ),
                ),
              ));
            }

            children.add(Positioned(
              left: pos.dx - size / 2,
              top: pos.dy - size / 2,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(angle: angle, child: _ball(size)),
              ),
            ));
          }

          // تناثر عند الهبوط
          if (v >= 0.8) {
            final b = Curves.easeOutCubic.transform(((v - 0.8) / 0.2).clamp(0.0, 1.0));
            for (var i = 0; i < 8; i++) {
              final a = i * math.pi / 4 + 0.3;
              final d = 8 + 26 * b;
              final p = widget.end + Offset(math.cos(a) * d, math.sin(a) * d);
              final r = 3.2 * (1 - b) + 0.6;
              children.add(Positioned(
                left: p.dx - r,
                top: p.dy - r,
                child: Container(
                  width: r * 2,
                  height: r * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (i.isEven ? RastUi.purple : RastUi.blue).withValues(alpha: 1 - b),
                  ),
                ),
              ));
            }
            final ring = 14 + 22 * b;
            children.add(Positioned(
              left: widget.end.dx - ring,
              top: widget.end.dy - ring,
              child: Container(
                width: ring * 2,
                height: ring * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: RastUi.purple.withValues(alpha: 0.55 * (1 - b)), width: 2),
                ),
              ),
            ));
          }

          return Stack(children: children);
        },
      ),
    );
  }

  Widget _ball(double size) {
    final url = widget.imageUrl;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RastUi.brandGradient,
        boxShadow: [
          BoxShadow(color: RastUi.purple.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _iconFallback(size),
                placeholder: (_, __) => _iconFallback(size),
              )
            : _iconFallback(size),
      ),
    );
  }

  Widget _iconFallback(double size) => ColoredBox(
        color: Colors.white,
        child: Center(child: Icon(widget.icon, color: RastUi.purple, size: size * 0.5)),
      );
}

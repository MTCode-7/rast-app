import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/widgets/cart_icon_button.dart';
import 'package:rast/core/widgets/fly_to_cart.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// إشعار عائم أنيق بعد الإضافة للسلة (بديل SnackBar):
/// علامة صح تُرسم، عدد العناصر، وزر «عرض السلة». يُغلق تلقائياً أو بالسحب للأسفل.
class CartAddedToast {
  CartAddedToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show({
    required OverlayState overlay,
    required String lang,
    required VoidCallback onViewCart,
  }) {
    hide();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        lang: lang,
        onViewCart: () {
          hide();
          onViewCart();
        },
        onDismiss: hide,
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 4200), hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    final e = _current;
    _current = null;
    if (e != null && e.mounted) e.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.lang, required this.onViewCart, required this.onDismiss});

  final String lang;
  final VoidCallback onViewCart;
  final VoidCallback onDismiss;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _check.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final count = math.max(0, context.watch<CartService>().itemsCount - FlyToCart.pending.value);
    final dark = RastUi.isDark(context);

    return Positioned(
      left: 14,
      right: 14,
      bottom: bottomInset + 96,
      child: AnimatedBuilder(
        animation: _enter,
        builder: (context, child) {
          final t = Curves.easeOutBack.transform(_enter.value);
          return Opacity(
            opacity: _enter.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 60 + _drag),
              child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
            ),
          );
        },
        child: GestureDetector(
          onVerticalDragUpdate: (d) => setState(() => _drag = math.max(0, _drag + d.delta.dy)),
          onVerticalDragEnd: (_) {
            if (_drag > 40) {
              widget.onDismiss();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: dark ? RastUi.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: RastUi.purple.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 26, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: AnimatedBuilder(
                      animation: _check,
                      builder: (_, __) => CustomPaint(painter: _CheckPainter(_check.value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t('addedToCart', widget.lang),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: RastUi.primaryText(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            AppStrings.t('cartItemsCount', widget.lang).replaceAll('%d', '$count'),
                            key: ValueKey(count),
                            style: TextStyle(fontSize: 12, color: RastUi.secondaryText(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CartIconButton(
                    size: 38,
                    iconColor: RastUi.purple,
                    backgroundColor: RastUi.purple.withValues(alpha: 0.08),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RastUi.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: widget.onViewCart,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(
                          AppStrings.t('viewCart', widget.lang),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// دائرة خضراء تمتلئ ثم تُرسم علامة الصح بخط متحرك
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final circleT = Curves.easeOutBack.transform((t / 0.45).clamp(0.0, 1.0));
    canvas.drawCircle(c, r * circleT, Paint()..color = const Color(0xFF16A34A));
    final checkT = Curves.easeOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
    if (checkT <= 0) return;
    final p1 = Offset(c.dx - r * 0.42, c.dy + r * 0.02);
    final p2 = Offset(c.dx - r * 0.1, c.dy + r * 0.34);
    final p3 = Offset(c.dx + r * 0.45, c.dy - r * 0.3);
    final path = Path()..moveTo(p1.dx, p1.dy);
    final first = (p2 - p1).distance;
    final second = (p3 - p2).distance;
    final len = (first + second) * checkT;
    if (len <= first) {
      final q = p1 + (p2 - p1) * (len / first);
      path.lineTo(q.dx, q.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final q = p2 + (p3 - p2) * ((len - first) / second);
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

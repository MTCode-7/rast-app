import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// مكتبة الحركة الموحّدة في التطبيق: دخول القوائم، ضغط البطاقات، انتقال الصفحات،
/// قلب المفضلة، واحتفال النجاح. كلها خفيفة ومحسوبة لتبقى سلسة على الأجهزة المتوسطة.

extension RastEntrance on Widget {
  /// دخول متتابع لعناصر القوائم: ظهور وانزلاق خفيف للأعلى، بتأخير صغير حسب الترتيب
  /// (حتى العنصر الثامن فقط حتى لا تتأخر القوائم الطويلة).
  Widget entrance(int index, {double offset = 0.10}) => animate(
        delay: (math.min(index, 8) * 55).ms,
      )
          .fadeIn(duration: 380.ms, curve: Curves.easeOut)
          .slideY(begin: offset, end: 0, duration: 460.ms, curve: Curves.easeOutCubic)
          .scaleXY(begin: 0.98, end: 1, duration: 460.ms, curve: Curves.easeOutCubic);
}

/// يصغر العنصر قليلاً عند الضغط ثم يرتد (إحساس زر حقيقي) مع اهتزاز خفيف.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.965, this.haptic = true});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset? _origin;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _origin = e.position;
        _set(true);
      },
      // عند بدء التمرير لا نُبقي البطاقة مضغوطة
      onPointerMove: (e) {
        if (_down && _origin != null && (e.position - _origin!).distance > 10) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Duration(milliseconds: _down ? 110 : 260),
          curve: _down ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

/// انتقال صفحات موحّد: الصفحة الجديدة تنزلق قليلاً من جهة القراءة وتظهر تدريجياً،
/// والقديمة تتراجع قليلاً وتخفت (أنعم من الانتقال الافتراضي في أندرويد).
class RastPageTransitionsBuilder extends PageTransitionsBuilder {
  const RastPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dir = rtl ? -1.0 : 1.0;
    final enter = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: Offset(0.12 * dir, 0), end: Offset.zero).animate(enter),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: animation, curve: const Interval(0, 0.7, curve: Curves.easeOut)),
        ),
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset.zero, end: Offset(-0.06 * dir, 0)).animate(exit),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.55).animate(exit),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// قلب المفضلة: عند التفعيل ينبض ويطلق حلقة وجزيئات صغيرة.
class AnimatedFavoriteIcon extends StatefulWidget {
  const AnimatedFavoriteIcon({
    super.key,
    required this.active,
    this.size = 22,
    this.activeColor = const Color(0xFFFF4D61),
    this.inactiveColor,
  });

  final bool active;
  final double size;
  final Color activeColor;
  final Color? inactiveColor;

  @override
  State<AnimatedFavoriteIcon> createState() => _AnimatedFavoriteIconState();
}

class _AnimatedFavoriteIconState extends State<AnimatedFavoriteIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(AnimatedFavoriteIcon old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      HapticFeedback.lightImpact();
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final animating = _c.isAnimating;
        final heartScale = animating ? (t < 0.25 ? 1 - 0.35 * (t / 0.25) : 0.65 + 0.35 * Curves.elasticOut.transform((t - 0.25) / 0.75)) : 1.0;
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (animating) ...[
                // حلقة تتسع
                Container(
                  width: s * (0.6 + 1.1 * Curves.easeOut.transform(t)),
                  height: s * (0.6 + 1.1 * Curves.easeOut.transform(t)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.activeColor.withValues(alpha: (1 - t) * 0.6), width: 2 * (1 - t) + 0.5),
                  ),
                ),
                // جزيئات
                for (var i = 0; i < 7; i++)
                  Transform.translate(
                    offset: Offset(
                      math.cos(i * 2 * math.pi / 7 - math.pi / 2) * s * (0.3 + 0.75 * Curves.easeOut.transform(t)),
                      math.sin(i * 2 * math.pi / 7 - math.pi / 2) * s * (0.3 + 0.75 * Curves.easeOut.transform(t)),
                    ),
                    child: Container(
                      width: s * 0.16 * (1 - t) + 1,
                      height: s * 0.16 * (1 - t) + 1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (i.isEven ? widget.activeColor : RastUi.purple).withValues(alpha: 1 - t),
                      ),
                    ),
                  ),
              ],
              Transform.scale(
                scale: heartScale,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(
                    widget.active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(widget.active),
                    color: widget.active ? widget.activeColor : (widget.inactiveColor ?? widget.activeColor),
                    size: s,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// احتفال النجاح (دفع/حجز): قصاصات ملوّنة تتساقط من أعلى الشاشة لثانيتين تقريباً.
class Celebration {
  Celebration._();

  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    HapticFeedback.heavyImpact();
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ConfettiLayer(onDone: () => entry.remove()));
    overlay.insert(entry);
  }
}

class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _rand = math.Random();
  late final List<_Piece> _pieces = List.generate(70, (_) => _Piece.random(_rand));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
      ),
    );
  }
}

class _Piece {
  _Piece(this.x, this.delay, this.speed, this.drift, this.spin, this.size, this.color, this.circle);

  factory _Piece.random(math.Random r) {
    const colors = [Color(0xFF7C3AED), Color(0xFF0EA5E9), Color(0xFF16A34A), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFFF43F5E)];
    return _Piece(
      r.nextDouble(),
      r.nextDouble() * 0.35,
      0.75 + r.nextDouble() * 0.6,
      (r.nextDouble() - 0.5) * 0.25,
      (r.nextDouble() - 0.5) * 14,
      5 + r.nextDouble() * 6,
      colors[r.nextInt(colors.length)],
      r.nextBool(),
    );
  }

  final double x, delay, speed, drift, spin, size;
  final Color color;
  final bool circle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + (size.height + 40) * local * p.speed;
      final x = size.width * (p.x + p.drift * local) + math.sin(local * 10 + p.x * 20) * 12;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), const Radius.circular(1.5)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/widgets/rast_kit.dart';

/// قطع مرئية مشتركة لبطاقات المختبرات وصفحة المختبر:
/// صورة الغلاف (أو بديل بتدرج الهوية)، حالة الدوام الآن، والأزرار الزجاجية فوق الصور.

/// رابط صورة غلاف المختبر: الغلاف المرفوع، وإلا أول صورة من معرضه.
String? labCoverUrl(Map<dynamic, dynamic> lab) {
  final cover = ApiConfig.resolveImageUrl(lab['cover_image_url'], lab['cover_image']);
  if (cover != null && cover.isNotEmpty) return cover;
  for (final key in ['gallery', 'images']) {
    final list = lab[key];
    if (list is List) {
      for (final e in list) {
        final url = ApiConfig.resolveImageUrl(e);
        if (url != null && url.isNotEmpty) return url;
      }
    }
  }
  return null;
}

String? labLogoUrl(Map<dynamic, dynamic> lab) => ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);

/// «HH:mm» → «10م» / «4:30م» (أو 10 PM)
String labClock(String? hhmm, String lang) {
  if (hhmm == null || hhmm.length < 4) return '';
  final parts = hhmm.split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final mm = m == 0 ? '' : ':${m.toString().padLeft(2, '0')}';
  final pm = h >= 12;
  return lang == 'en' ? '$h12$mm ${pm ? 'PM' : 'AM'}' : '$h12$mm${pm ? 'م' : 'ص'}';
}

/// ساعات العمل بمفاتيح 0=الأحد … 6=السبت ({open, close}) إن كانت مرسلة كخريطة.
Map<int, Map<String, String>>? labWeeklyHours(Map<dynamic, dynamic> lab) {
  final raw = lab['working_hours'];
  if (raw is! Map || raw.isEmpty) return null;
  final out = <int, Map<String, String>>{};
  raw.forEach((k, v) {
    final day = int.tryParse(k.toString());
    if (day == null || day < 0 || day > 6 || v is! Map) return;
    final open = v['open']?.toString() ?? '';
    final close = v['close']?.toString() ?? '';
    if (open.isNotEmpty && close.isNotEmpty) out[day] = {'open': open, 'close': close};
  });
  return out.isEmpty ? null : out;
}

/// حالة الدوام: من الخادم (open_status) إن وُجدت، وإلا تُحسب محلياً من ساعات العمل.
({bool known, bool open, String? opensAt, String? closesAt}) labOpenStatus(Map<dynamic, dynamic> lab) {
  final s = lab['open_status'];
  if (s is Map && s['known'] == true) {
    return (
      known: true,
      open: s['open'] == true,
      opensAt: s['opens_at']?.toString(),
      closesAt: s['closes_at']?.toString(),
    );
  }
  final week = labWeeklyHours(lab);
  if (week == null) return (known: false, open: false, opensAt: null, closesAt: null);
  final now = DateTime.now();
  final today = week[now.weekday % 7]; // Dart: الإثنين=1 … الأحد=7 → الأحد=0
  if (today == null) return (known: true, open: false, opensAt: null, closesAt: null);
  final cur = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final open = today['open']!;
  final close = today['close']!;
  final isOpen = close.compareTo(open) > 0
      ? (cur.compareTo(open) >= 0 && cur.compareTo(close) < 0)
      : (cur.compareTo(open) >= 0 || cur.compareTo(close) < 0);
  return (known: true, open: isOpen, opensAt: open, closesAt: close);
}

/// بديل الغلاف: تدرج الهوية مع نقش هندسي ناعم وشعار باهت كبير.
class LabCoverFallback extends StatelessWidget {
  const LabCoverFallback({super.key, this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    // مختبر بلا صورة غلاف: نعرض شعاره نفسه واضحاً على خلفية فاتحة (بدل خلفية بنفسجية فارغة)
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    if (!hasLogo) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: RastTokens.heroGradient)),
          CustomPaint(painter: _LabPatternPainter()),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) => ColoredBox(
        color: RastTokens.dark(context) ? const Color(0xFF14232F) : Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: c.maxWidth * 0.12, vertical: c.maxHeight * 0.14),
            child: RastNetImage(
              url: logoUrl,
              width: c.maxWidth,
              height: c.maxHeight,
              radius: 0,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _LabPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.12), size.height * 0.55, ring);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.12), size.height * 0.36, ring);
    canvas.drawCircle(Offset(size.width * 0.06, size.height * 0.95), size.height * 0.42, ring);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const step = 22.0;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        // نقاط خفيفة تتلاشى نحو المنتصف
        final d = (Offset(x, y) - Offset(size.width / 2, size.height / 2)).distance;
        final r = 1.1 * (d / math.max(size.width, size.height)).clamp(0.25, 1.0);
        canvas.drawCircle(Offset(x, y), r, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// شارة «مفتوح الآن · يغلق 10م» بنقطة نابضة. compact: نقطة ونص قصير فقط.
class LabOpenBadge extends StatelessWidget {
  const LabOpenBadge({super.key, required this.open, required this.lang, this.opensAt, this.closesAt, this.compact = false, this.onDark = false});

  final bool open;
  final String lang;
  final String? opensAt;
  final String? closesAt;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = open ? RastTokens.success : RastTokens.danger;
    final closes = labClock(closesAt, lang);
    final opens = labClock(opensAt, lang);
    final label = compact
        ? (open ? L(lang, 'مفتوح', 'Open') : L(lang, 'مغلق', 'Closed'))
        : open
            ? (closes.isNotEmpty ? L(lang, 'مفتوح الآن · يغلق $closes', 'Open now · closes $closes') : L(lang, 'مفتوح الآن', 'Open now'))
            : (opens.isNotEmpty ? L(lang, 'مغلق الآن · يفتح $opens', 'Closed · opens $opens') : L(lang, 'مغلق الآن', 'Closed now'));
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.92) : color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w800, height: 1.1)),
        ],
      ),
    );
  }
}

/// زر دائري أبيض شبه شفاف بظل ناعم فوق الصور (رجوع، مفضلة، مشاركة…).
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({super.key, required this.child, this.onTap, this.size = 42});

  final Widget child;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = RastTokens.dark(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? const Color(0xE6142230) : Colors.white.withValues(alpha: 0.94),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Center(child: child)),
      ),
    );
  }
}

/// تنسيق المسافة: «850 م» أو «3.2 كم».
String labDistanceLabel(double km, String lang) => km < 1
    ? L(lang, '${(km * 1000).round()} م', '${(km * 1000).round()} m')
    : L(lang, '${km.toStringAsFixed(1)} كم', '${km.toStringAsFixed(1)} km');

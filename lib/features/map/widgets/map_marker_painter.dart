import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rast/core/widgets/rast_kit.dart';

/// يرسم دبابيس الخريطة كصور: فقاعة بالسعر (أو التقييم) مع سهم، ودائرة عدد للتجميع.
/// الصور تُخزَّن مؤقتاً حسب النص والحالة لتجنّب إعادة الرسم.
class MapMarkerPainter {
  MapMarkerPainter._();

  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> pill({
    required String text,
    required bool selected,
    required bool offer,
    required double dpr,
    bool dimmed = false,
  }) async {
    final key = 'p|$text|$selected|$offer|$dimmed|$dpr';
    final cached = _cache[key];
    if (cached != null) return cached;

    final scale = dpr;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12.5 * scale,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : RastTokens.brand,
          fontFamily: 'Cairo',
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    final padH = 10 * scale;
    final padV = 5 * scale;
    final arrow = 7 * scale;
    final dot = offer ? 8 * scale : 0.0;
    final w = tp.width + padH * 2 + (offer ? dot + 4 * scale : 0);
    final h = tp.height + padV * 2;
    final shadow = 4 * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(shadow, shadow, w, h), Radius.circular(h / 2));

    canvas.drawRRect(rect.shift(Offset(0, 1.5 * scale)), Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale));

    final fill = Paint();
    if (selected) {
      fill.shader = const LinearGradient(colors: [Color(0xFF6A1B68), Color(0xFF395395)])
          .createShader(Rect.fromLTWH(shadow, shadow, w, h));
    } else {
      fill.color = dimmed ? const Color(0xFFF1F0F5) : Colors.white;
    }
    canvas.drawRRect(rect, fill);
    if (!selected) {
      canvas.drawRRect(rect, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * scale
        ..color = RastTokens.brand.withValues(alpha: 0.35));
    }

    // السهم أسفل الفقاعة
    final cx = shadow + w / 2;
    final path = Path()
      ..moveTo(cx - arrow, shadow + h - 1)
      ..lineTo(cx, shadow + h + arrow)
      ..lineTo(cx + arrow, shadow + h - 1)
      ..close();
    canvas.drawPath(path, selected ? (Paint()..color = const Color(0xFF52398F)) : (Paint()..color = dimmed ? const Color(0xFFF1F0F5) : Colors.white));

    var x = shadow + padH;
    if (offer) {
      canvas.drawCircle(Offset(x + dot / 2, shadow + h / 2), dot / 2, Paint()..color = selected ? const Color(0xFFFFC400) : RastTokens.danger);
      x += dot + 4 * scale;
    }
    tp.paint(canvas, Offset(x, shadow + padV));

    final img = await recorder.endRecording().toImage((w + shadow * 2).ceil(), (h + arrow + shadow * 2).ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final desc = BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: dpr);
    _cache[key] = desc;
    return desc;
  }

  static Future<BitmapDescriptor> cluster({required int count, required double dpr}) async {
    final key = 'c|$count|$dpr';
    final cached = _cache[key];
    if (cached != null) return cached;

    final size = (count < 10 ? 40.0 : count < 100 ? 46.0 : 52.0) * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2 + 4 * dpr, size / 2 + 4 * dpr);
    canvas.drawCircle(c, size / 2 + 4 * dpr, Paint()..color = RastTokens.brand.withValues(alpha: 0.18));
    canvas.drawCircle(c, size / 2, Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF6A1B68), Color(0xFF395395)])
          .createShader(Rect.fromCircle(center: c, radius: size / 2)));
    canvas.drawCircle(c, size / 2, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * dpr
      ..color = Colors.white);
    final tp = TextPainter(
      text: TextSpan(text: '$count', style: TextStyle(fontSize: 15 * dpr, fontWeight: FontWeight.w900, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));

    final total = (size + 8 * dpr).ceil();
    final img = await recorder.endRecording().toImage(total, total);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final desc = BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: dpr);
    _cache[key] = desc;
    return desc;
  }
}

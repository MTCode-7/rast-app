import 'package:flutter/material.dart';

/// مساعد للأحجام والتنسيق المتجاوب مع مختلف الشاشات
class Responsive {
  static double width(BuildContext context, [double fraction = 1]) =>
      MediaQuery.sizeOf(context).width * fraction;

  static double height(BuildContext context, [double fraction = 1]) =>
      MediaQuery.sizeOf(context).height * fraction;

  static bool get isSmallScreen => _screenWidth < 360;
  static bool get isMediumScreen => _screenWidth >= 360 && _screenWidth < 600;
  static bool get isLargeScreen => _screenWidth >= 600;

  static double _screenWidth = 375;
  static void updateScreenSize(BuildContext context) {
    _screenWidth = MediaQuery.sizeOf(context).width;
  }

  /// مسافات متجاوبة
  static double spacing(BuildContext context, [double base = 16]) =>
      base * _scaleFactor(context);

  /// حجم خط متجاوب - يمنع التصغير الشديد على الشاشات الكبيرة
  static double fontSize(BuildContext context, double base) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / 375).clamp(0.85, 1.15);
    return base * scale;
  }

  static double _scaleFactor(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w / 375).clamp(0.9, 1.2);
  }

  /// عرض بطاقة الباقة في القائمة الأفقية (حوالي 2.5 باقة ظاهرة - أكبر قليلاً)
  static double packageCardWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 600) return 200;
    return (w - spacing(context, 16) * 2 - spacing(context, 12) * 2) / 2.4;
  }

  /// ارتفاع الكاروسيل
  static double carouselHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.22).clamp(140.0, 200.0);
  }

  /// حجم أيقونة الفئة
  static double categoryIconSize(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.16).clamp(56.0, 72.0);

  /// نص قابل للتكيف مع textScaleFactor
  static TextStyle scalableTextStyle(BuildContext context, TextStyle base) =>
      base.copyWith(
        fontSize: base.fontSize != null ? fontSize(context, base.fontSize!) : null,
      );
}

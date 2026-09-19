import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ثيم فاخر مستوحى من الفخامة الطبية - ألوان aurora وتأثيرات زجاجية
class AppTheme {
  // ألوان أساسية - لوحة أورورا الفاخرة
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color secondary = Color(0xFF06B6D4);
  static const Color accent = Color(0xFF2DD4BF);
  static const Color goldAccent = Color(0xFFD4A853);
  static const Color warmGold = Color(0xFFEAB308);
  static const Color surface = Color(0xFFF8FFFE);
  static const Color surfaceVariant = Color(0xFFE6F5F3);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF475569);

  /// تدرجات فاخرة متعددة
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF0D9488),
      Color(0xFF0F766E),
      Color(0xFF134E4A),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D9488),
      Color(0xFF06B6D4),
      Color(0xFF2DD4BF),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2DD4BF),
      Color(0xFF14B8A6),
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFCD34D),
      Color(0xFFD4A853),
    ],
  );

  /// تدرج الخلفية الفاخرة
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF0FDFA),
      Color(0xFFF8FFFE),
      Color(0xFFF1F5F9),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  /// ظلال فاخرة متعددة الطبقات
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get cardShadowElevated => [
        BoxShadow(
          color: primary.withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get softGlow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get goldGlow => [
        BoxShadow(
          color: warmGold.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 2),
          spreadRadius: -2,
        ),
      ];

  /// بطاقات فاخرة بتأثير زجاجي خفيف
  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.5,
        ),
        boxShadow: cardShadow,
      );

  static BoxDecoration cardDecorationElevated({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: primary.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: cardShadowElevated,
      );

  /// بطاقة بتدرج فاخر
  static BoxDecoration cardDecorationGradient() => BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            primary.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(
          color: primary.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: cardShadow,
      );

  /// صندوق بحث فاخر بتأثير زجاجي
  static BoxDecoration searchBoxDecoration(BuildContext context) => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primary.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration chipSelectedDecoration() => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.2),
            primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      );

  static BoxDecoration chipDecoration() => BoxDecoration(
        color: surfaceVariant.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      );

  /// أنماط نصوص فاخرة
  static TextStyle headlineLarge(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: color ?? onSurface,
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle headlineMedium(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: color ?? onSurface,
        letterSpacing: -0.3,
      );

  static TextStyle titleLarge(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? onSurface,
      );

  static TextStyle bodyLarge(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color ?? onSurface,
        height: 1.45,
      );

  static TextStyle bodyMedium(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: color ?? onSurfaceVariant,
        height: 1.5,
      );

  static TextStyle caption(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? onSurfaceVariant,
      );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Cairo',
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: onPrimary,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: onSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant.withValues(alpha: 0.8),
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: surfaceVariant, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        hintStyle: const TextStyle(color: onSurfaceVariant, fontSize: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }

  /// ثيم الوضع الداكن الفاخر
  static ThemeData get darkTheme {
    const darkSurface = Color(0xFF0F1419);
    const darkSurfaceVariant = Color(0xFF1A2332);
    const darkOnSurface = Color(0xFFE7EDF3);
    const darkOnSurfaceVariant = Color(0xFF94A3B8);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: darkSurface,
      fontFamily: 'Cairo',
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        secondary: secondary,
        surface: darkSurface,
        error: error,
        onPrimary: Colors.black87,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: darkOnSurface,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: darkOnSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: darkOnSurface, size: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceVariant,
        selectedColor: primaryLight.withValues(alpha: 0.3),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurfaceVariant,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: darkSurfaceVariant, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        hintStyle: const TextStyle(color: darkOnSurfaceVariant, fontSize: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.black87,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: primaryLight, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }
}

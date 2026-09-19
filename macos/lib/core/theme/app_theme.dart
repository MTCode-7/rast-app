import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ثيم عصري مميز — بنفسجي وكحلي مع لمسة ذهبية
class AppTheme {
  // لوحة ألوان جديدة — بنفسجي عميق وكحلي
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFFF59E0B);
  static const Color goldAccent = Color(0xFFB45309);
  static const Color warmGold = Color(0xFFFBBF24);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceVariant = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF475569);

  /// تدرجات رئيسية
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14B8A6), Color(0xFF0F766E), Color(0xFF155E75)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF0F766E)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
  );

  /// خلفية الشاشة
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFF0F9FF),
      Color(0xFFF0FDFA),
      Color(0xFFEFF6FF),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  /// ظلال البطاقات
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 5),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
      spreadRadius: -1,
    ),
  ];

  static List<BoxShadow> get cardShadowElevated => [
    BoxShadow(
      color: primary.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get softGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.25),
      blurRadius: 18,
      offset: const Offset(0, 3),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: warmGold.withValues(alpha: 0.4),
      blurRadius: 14,
      offset: const Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  /// زوايا أنعم (20 بدل 24) لمظهر أحدث
  static double get radiusCard => 20;
  static double get radiusButton => 18;
  static double get radiusInput => 18;

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
    color: color ?? Colors.white,
    borderRadius: BorderRadius.circular(radiusCard),
    border: Border.all(color: Colors.white.withValues(alpha: 0.98), width: 1),
    boxShadow: cardShadow,
  );

  /// بطاقة تتكيف مع الوضع الداكن (استخدم هذا في الشاشات)
  static BoxDecoration cardDecorationFor(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    final surface = color ?? theme.colorScheme.surface;
    final borderColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outline.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.98);
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radiusCard),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: cardShadow,
    );
  }

  static BoxDecoration cardDecorationElevated({Color? color}) => BoxDecoration(
    color: color ?? Colors.white,
    borderRadius: BorderRadius.circular(radiusCard),
    border: Border.all(color: primary.withValues(alpha: 0.08), width: 1),
    boxShadow: cardShadowElevated,
  );

  /// بطاقة مرتفعة تتكيف مع الوضع الداكن
  static BoxDecoration cardDecorationElevatedFor(
    BuildContext context, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final surface = color ?? theme.colorScheme.surface;
    final borderColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outline.withValues(alpha: 0.2)
        : primary.withValues(alpha: 0.08);
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radiusCard),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: cardShadowElevated,
    );
  }

  static BoxDecoration cardDecorationGradient() => BoxDecoration(
    borderRadius: BorderRadius.circular(radiusCard),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, primary.withValues(alpha: 0.03)],
    ),
    border: Border.all(color: primary.withValues(alpha: 0.08), width: 1),
    boxShadow: cardShadow,
  );

  static BoxDecoration searchBoxDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHigh
        : Colors.white.withValues(alpha: 0.98);
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radiusInput),
      border: Border.all(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.outline.withValues(alpha: 0.3)
            : primary.withValues(alpha: 0.12),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
        BoxShadow(
          color: Colors.black.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.2 : 0.03,
          ),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration chipSelectedDecoration() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary.withValues(alpha: 0.2), primary.withValues(alpha: 0.08)],
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.5),
  );

  static BoxDecoration chipDecoration() => BoxDecoration(
    color: surfaceVariant.withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(16),
  );

  /// أنماط نصوص — تعتمد على خط التطبيق (Tajawal من الثيم)
  static TextStyle headlineLarge(BuildContext context, {Color? color}) =>
      TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: color ?? onSurface,
        letterSpacing: -0.5,
        height: 1.25,
      );

  static TextStyle headlineMedium(BuildContext context, {Color? color}) =>
      TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: color ?? onSurface,
        letterSpacing: -0.3,
      );

  static TextStyle titleLarge(BuildContext context, {Color? color}) =>
      TextStyle(
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

  static TextStyle bodyMedium(BuildContext context, {Color? color}) =>
      TextStyle(
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

  /// ثيم فاتح مع ألوان مخصّصة (من API): اللون الأول للعناصر الرئيسية، الثاني للروابط وعرض الكل
  static ThemeData lightThemeWithColors({
    required Color primary,
    required Color secondary,
  }) {
    final base = lightTheme;
    return base.copyWith(
      primaryColor: primary,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: secondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style!.copyWith(
          backgroundColor: WidgetStatePropertyAll(primary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style!.copyWith(
          foregroundColor: WidgetStatePropertyAll(primary),
          side: WidgetStatePropertyAll(BorderSide(color: primary, width: 2)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: secondary),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: primary.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  /// ثيم داكن مع ألوان مخصّصة (من API)
  static ThemeData darkThemeWithColors({
    required Color primary,
    required Color secondary,
  }) {
    final base = darkTheme;
    return base.copyWith(
      primaryColor: primary,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: secondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style!.copyWith(
          backgroundColor: WidgetStatePropertyAll(primary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style!.copyWith(
          foregroundColor: WidgetStatePropertyAll(primary),
          side: WidgetStatePropertyAll(BorderSide(color: primary, width: 2)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: secondary),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: primary.withValues(alpha: 0.3),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme);
    final primaryTextTheme = GoogleFonts.cairoTextTheme(base.primaryTextTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: onPrimary,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.3,
          color: onSurface,
        ),
        iconTheme: const IconThemeData(color: onSurface, size: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant.withValues(alpha: 0.8),
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: surfaceVariant, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 18,
        ),
        hintStyle: TextStyle(
          color: onSurfaceVariant,
          fontSize: 16,
          fontFamily: GoogleFonts.cairo().fontFamily,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: textTheme.titleSmall!.copyWith(
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  /// ثيم الوضع الداكن
  static ThemeData get darkTheme {
    const darkSurface = Color(0xFF07131A);
    const darkSurfaceVariant = Color(0xFF0F1D27);
    const darkOnSurface = Color(0xFFE2E8F0);
    const darkOnSurfaceVariant = Color(0xFF94A3B8);

    final base = ThemeData.dark();
    final textTheme = GoogleFonts.cairoTextTheme(
      base.textTheme,
    ).apply(bodyColor: darkOnSurface, displayColor: darkOnSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: darkSurface,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: textTheme,
      primaryTextTheme: GoogleFonts.cairoTextTheme(base.primaryTextTheme),
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
        titleTextStyle: textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.3,
          color: darkOnSurface,
        ),
        iconTheme: IconThemeData(color: darkOnSurface, size: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceVariant,
        selectedColor: primaryLight.withValues(alpha: 0.3),
        labelStyle: textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurfaceVariant,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: darkSurfaceVariant, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 18,
        ),
        hintStyle: TextStyle(
          color: darkOnSurfaceVariant,
          fontSize: 16,
          fontFamily: GoogleFonts.cairo().fontFamily,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.black87,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: textTheme.titleSmall!.copyWith(
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

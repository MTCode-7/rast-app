import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/services/permissions_service.dart';
import 'package:rast/core/services/push_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/splash/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase is configured per platform after the app credentials are added.
  }
  await AuthService.init();
  // نسخة التطبيق والجهاز في رؤوس الطلبات (لا تؤخر الفتح)
  unawaited(ApiClient().attachDeviceInfo());
  await AnalyticsService.init();
  // ربط المستخدم المسجّل مسبقاً بأدوات القياس (Firebase و TikTok)
  final signedIn = AuthService.currentUser;
  if (AuthService.isLoggedIn && signedIn != null) {
    unawaited(AnalyticsService.setUserId(signedIn.id.toString(), email: signedIn.email, phone: signedIn.phone));
  }
  await PermissionsService.requestLocationPermission();
  runApp(const RastApp());
  // إشعارات الجوال: بعد ظهور التطبيق حتى لا يتأخر فتحه
  unawaited(PushService.init());
}

class RastApp extends StatelessWidget {
  const RastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => CartService()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (_, settings, __) {
          final isDark = settings.isDarkMode;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );
          final lang = settings.language;
          return MaterialApp(
            navigatorKey: PushService.navigatorKey,
            title: AppStrings.t('appName', lang),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightThemeWithColors(
              primary: settings.primaryColor,
              secondary: settings.secondaryColor,
            ).copyWith(pageTransitionsTheme: _pageTransitions),
            darkTheme: AppTheme.darkThemeWithColors(
              primary: settings.primaryColor,
              secondary: settings.secondaryColor,
            ).copyWith(pageTransitionsTheme: _pageTransitions),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            locale: settings.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

/// انتقال صفحات أنعم في أندرويد؛ آيفون يبقى بانتقاله الأصلي (مع سحب الرجوع من الحافة)
const _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: RastPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

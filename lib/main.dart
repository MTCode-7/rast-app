import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/services/permissions_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/splash/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  await PermissionsService.requestLocationPermission();
  runApp(const RastApp());
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
            title: AppStrings.t('appName', lang),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightThemeWithColors(
              primary: settings.primaryColor,
              secondary: settings.secondaryColor,
            ),
            darkTheme: AppTheme.darkThemeWithColors(
              primary: settings.primaryColor,
              secondary: settings.secondaryColor,
            ),
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

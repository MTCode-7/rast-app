import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/permissions_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/bookings/screens/bookings_screen.dart';
import 'package:rast/features/home/screens/home_screen.dart';
import 'package:rast/features/labs/screens/labs_screen.dart';
import 'package:rast/features/profile/screens/profile_screen.dart';

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
    return ChangeNotifierProvider(
      create: (_) => AppSettingsProvider(),
      child: Consumer<AppSettingsProvider>(
        builder: (_, settings, __) {
          final isDark = settings.isDarkMode;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ),
          );
          return MaterialApp(
            title: 'راست',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            locale: settings.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainScaffold(),
          );
        },
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    BookingsScreen(),
    LabsScreen(),
    ProfileScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.home_rounded, 'الرئيسية'),
    _NavItem(Icons.event_note_rounded, 'الحجوزات'),
    _NavItem(Icons.business_rounded, 'المختبرات'),
    _NavItem(Icons.person_rounded, 'الملف'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    return Directionality(
      textDirection: settings.textDirection,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // خلفية فاخرة - لا تمنع التفاعل
          Positioned.fill(
            child: IgnorePointer(
              child: _buildLuxuryBackground(),
            ),
          ),
          // المحتوى فوق الخلفية
          Positioned.fill(
            child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            body: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 68,
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
            bottomNavigationBar: _buildGlassNavBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryBackground() {
    final isDark = context.watch<AppSettingsProvider>().isDarkMode;
    final gradient = isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F1419),
              const Color(0xFF0D1117),
              const Color(0xFF0A0E12),
            ],
            stops: const [0.0, 0.4, 1.0],
          )
        : AppTheme.backgroundGradient;
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      child: Stack(
        children: [
          // دائرة زخرفية علوية يمين
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.08),
                    AppTheme.primary.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
            ),
          ),
          )
              .animate()
              .fadeIn(duration: 1000.ms)
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOut),
          // دائرة زخرفية سفلى يسار
          Positioned(
            bottom: -60,
            left: -100,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withValues(alpha: 0.06),
                    AppTheme.secondary.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
            ),
          ),
          )
              .animate()
              .fadeIn(duration: 1000.ms, delay: 300.ms)
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildGlassNavBar() {
    final isDark = context.watch<AppSettingsProvider>().isDarkMode;
    final theme = Theme.of(context);
    final navColor = isDark ? theme.colorScheme.surface : Colors.white;
    final iconColor = isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.onSurfaceVariant;
    return CurvedNavigationBar(
        index: _currentIndex,
        height: 68,
        backgroundColor: Colors.transparent,
        color: navColor,
        buttonBackgroundColor: AppTheme.primary,
        animationDuration: const Duration(milliseconds: 350),
        animationCurve: Curves.easeInOutCubic,
        onTap: (index) => setState(() => _currentIndex = index),
        items: List.generate(
          _navItems.length,
          (i) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              _navItems[i].icon,
              size: 28,
              color: _currentIndex == i
                  ? Colors.white
                  : iconColor.withValues(alpha: 0.7),
            ),
          ),
        ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

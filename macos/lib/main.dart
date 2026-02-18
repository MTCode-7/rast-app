import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/permissions_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/bookings/screens/bookings_screen.dart';
import 'package:rast/features/chat/screens/chat_screen.dart';
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

  List<_NavItem> _navItems(String lang) => [
    _NavItem(Icons.home_rounded, AppStrings.t('home', lang)),
    _NavItem(Icons.event_note_rounded, AppStrings.t('bookings', lang)),
    _NavItem(Icons.business_rounded, AppStrings.t('labs', lang)),
    _NavItem(Icons.person_rounded, AppStrings.t('profile', lang)),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    return Directionality(
      textDirection: settings.textDirection,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(child: _buildLuxuryBackground()),
          ),
          Positioned.fill(
            child: Scaffold(
              extendBody: true,
              backgroundColor: Colors.transparent,
              body: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 94,
                ),
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
              bottomNavigationBar: _buildGlassNavBar(),
              floatingActionButton: _buildChatFab(),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryBackground() {
    final settings = context.watch<AppSettingsProvider>();
    final isDark = settings.isDarkMode;
    final primary = settings.primaryColor;
    final secondary = settings.secondaryColor;
    final gradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07131A), Color(0xFF081924), Color(0xFF091B27)],
            stops: [0.0, 0.45, 1.0],
          )
        : AppTheme.backgroundGradient;

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: [
          Positioned(
                top: -40,
                left: -30,
                child: Transform.rotate(
                  angle: 0.4,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(42),
                      gradient: LinearGradient(
                        colors: [
                          secondary.withValues(alpha: 0.10),
                          primary.withValues(alpha: 0.04),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 900.ms)
              .slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
          Positioned(
                top: -100,
                right: -60,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primary.withValues(alpha: 0.08),
                        primary.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 1000.ms)
              .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOut),
          Positioned(
                bottom: -50,
                left: -80,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        secondary.withValues(alpha: 0.07),
                        secondary.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 1000.ms, delay: 300.ms)
              .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildChatFab() {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildGlassNavBar() {
    final settings = context.watch<AppSettingsProvider>();
    final isDark = settings.isDarkMode;
    final theme = Theme.of(context);
    final navItems = _navItems(settings.language);
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      theme.colorScheme.surface.withValues(alpha: 0.96),
                      theme.colorScheme.surfaceContainerHigh.withValues(
                        alpha: 0.93,
                      ),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.95),
                      theme.colorScheme.surface.withValues(alpha: 0.92),
                    ],
            ),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(
                alpha: isDark ? 0.30 : 0.12,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: List.generate(navItems.length, (i) {
              final selected = i == _currentIndex;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _currentIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: selected
                            ? LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            navItems[i].icon,
                            size: 22,
                            color: selected
                                ? Colors.white
                                : iconColor.withValues(alpha: 0.85),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            navItems[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: selected ? Colors.white : iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
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

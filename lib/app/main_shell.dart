import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/bookings/screens/bookings_screen.dart';
import 'package:rast/features/chat/screens/chat_screen.dart';
import 'package:rast/features/home/screens/home_screen.dart';
import 'package:rast/features/labs/screens/labs_screen.dart';
import 'package:rast/features/profile/screens/profile_screen.dart';

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
                  bottom: MediaQuery.of(context).padding.bottom + 76,
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
        : const LinearGradient(colors: [Colors.white, Colors.white]);

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
        gradient: RastUi.brandGradient,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: 50,
        height: 50,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.support_agent_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGlassNavBar() {
    final settings = context.watch<AppSettingsProvider>();
    final navItems = _navItems(settings.language);

    return SafeArea(
      top: false,
      child: Container(
        height: 82,
        decoration: const BoxDecoration(
          gradient: RastUi.brandGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 8),
          child: Row(
            children: List.generate(navItems.length, (i) {
              final selected = i == _currentIndex;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _currentIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            navItems[i].icon,
                            size: 23,
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.58),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            navItems[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.58),
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

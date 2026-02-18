import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/screens/register_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart'
    show AuthService, UserModel;
import 'package:rast/features/bookings/screens/bookings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    final lang = context.read<AppSettingsProvider>().language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: context.read<AppSettingsProvider>().textDirection,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(AppStrings.t('logoutConfirm', lang)),
          content: Text(AppStrings.t('logoutConfirmMessage', lang)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.t('cancel', lang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(AppStrings.t('logoutConfirm', lang)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Api.auth.logout();
      } catch (_) {}
      await AuthService.logout();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final theme = Theme.of(context);

    return Directionality(
      textDirection: settings.textDirection,
      child: AuthService.isLoggedIn
          ? _buildProfileView(theme, settings)
          : _buildGuestView(theme, settings),
    );
  }

  Widget _buildGuestView(ThemeData theme, AppSettingsProvider settings) {
    final lang = settings.language;
    return Container(
      decoration: BoxDecoration(gradient: settings.primaryGradient),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.spacing(context, 24)),
            child: Column(
              children: [
                Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .scale(begin: const Offset(0.88, 0.88)),
                SizedBox(height: Responsive.spacing(context, 24)),
                Text(
                  AppStrings.t('signInToContinue', lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.fontSize(context, 23),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 8)),
                Text(
                  AppStrings.t('manageDataSubtitle', lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: Responsive.fontSize(context, 14),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 26)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(Responsive.spacing(context, 20)),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF101928)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => _navigateToLogin(),
                          style: FilledButton.styleFrom(
                            textStyle: TextStyle(
                              fontSize: Responsive.fontSize(context, 16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(AppStrings.t('signIn', lang)),
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, 12)),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => _navigateToLogin(isRegister: true),
                          style: OutlinedButton.styleFrom(
                            textStyle: TextStyle(
                              fontSize: Responsive.fontSize(context, 16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(AppStrings.t('createAccount', lang)),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.08, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView(ThemeData theme, AppSettingsProvider settings) {
    final user = AuthService.currentUser!;
    final lang = settings.language;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          stretch: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: settings.primaryGradient,
              ),
            ),
            centerTitle: true,
            title: Text(
              AppStrings.t('profile', lang),
              style: TextStyle(
                color: Colors.white,
                fontSize: Responsive.fontSize(context, 17),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.spacing(context, 16),
              ),
              child: Column(
                children: [
                  _buildProfileHero(user)
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.09, end: 0),
                  SizedBox(height: Responsive.spacing(context, 12)),
                  _buildStatsRow(lang),
                  SizedBox(height: Responsive.spacing(context, 14)),
                  _buildPreferencesCard(settings, lang),
                  SizedBox(height: Responsive.spacing(context, 14)),
                  _buildActionTile(
                    icon: Icons.event_note_rounded,
                    title: AppStrings.t('myBookings', lang),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BookingsScreen()),
                    ),
                  ),
                  SizedBox(height: Responsive.spacing(context, 10)),
                  _buildActionTile(
                    icon: Icons.logout_rounded,
                    title: AppStrings.t('logout', lang),
                    onTap: _logout,
                    iconColor: Colors.red.shade500,
                    textColor: Colors.red.shade500,
                  ),
                  SizedBox(height: Responsive.spacing(context, 44)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHero(UserModel user) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.spacing(context, 18)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.13),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.20 : 0.05,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: Responsive.spacing(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 3)),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (user.phone != null)
                  Text(
                    user.phone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 13),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String lang) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            Icons.event_available_rounded,
            AppStrings.t('myBookings', lang),
            '24',
          ),
        ),
        SizedBox(width: Responsive.spacing(context, 10)),
        Expanded(
          child: _statCard(
            Icons.favorite_rounded,
            AppStrings.t('favorites', lang),
            '8',
          ),
        ),
        SizedBox(width: Responsive.spacing(context, 10)),
        Expanded(
          child: _statCard(Icons.verified_user_rounded, AppStrings.t('trusted', lang), "100%"),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String title, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 12)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.13),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(AppSettingsProvider settings, String lang) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.13),
        ),
      ),
      child: Column(
        children: [
          _buildPrefRow(
            icon: Icons.language_rounded,
            title: AppStrings.t('language', lang),
            child: InkWell(
              onTap: () => _showLanguageSheet(settings),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.isArabic
                          ? AppStrings.t('arabic', lang)
                          : AppStrings.t('english', lang),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 12)),
          _buildPrefRow(
            icon: Icons.dark_mode_rounded,
            title: AppStrings.t('darkMode', lang),
            child: Switch.adaptive(
              value: settings.isDarkMode,
              onChanged: (_) => settings.toggleDarkMode(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefRow({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final fgText = textColor ?? theme.colorScheme.onSurface;
    final fgIcon = iconColor ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 14),
            vertical: Responsive.spacing(context, 14),
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.13),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: fgIcon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: fgIcon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: fgText,
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.fontSize(context, 14),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet(AppSettingsProvider settings) {
    final lang = settings.language;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 20)),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 16)),
              Text(
                AppStrings.t('language', lang),
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 17),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 8)),
              _buildLangOption('ar', AppStrings.t('arabic', lang), settings),
              _buildLangOption('en', AppStrings.t('english', lang), settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangOption(
    String value,
    String label,
    AppSettingsProvider settings,
  ) {
    final isSelected = settings.language == value;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          settings.setLanguage(value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin({bool isRegister = false}) async {
    if (isRegister) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
    setState(() {});
  }
}

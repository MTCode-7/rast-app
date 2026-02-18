import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/features/auth/services/auth_service.dart' show AuthService, UserModel;
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/screens/register_screen.dart';
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: settings.textDirection,
      child: AuthService.isLoggedIn ? _buildProfileView(theme, isDark) : _buildGuestView(theme, isDark),
    );
  }

  Widget _buildGuestView(ThemeData theme, bool isDark) {
    final lang = context.read<AppSettingsProvider>().language;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D9488),
            Color(0xFF0F766E),
            Color(0xFF134E4A),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.spacing(context, 28)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGuestAvatar().animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                SizedBox(height: Responsive.spacing(context, 28)),
                Text(
                  AppStrings.t('signInToContinue', lang),
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 24),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.15, end: 0),
                SizedBox(height: Responsive.spacing(context, 8)),
                Text(
                  AppStrings.t('manageDataSubtitle', lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 15),
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, end: 0),
                SizedBox(height: Responsive.spacing(context, 40)),
                _buildGuestActions(lang).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestAvatar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      child: Icon(Icons.person_outline_rounded, size: 64, color: Colors.white.withValues(alpha: 0.95)),
    );
  }

  Widget _buildGuestActions(String lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 24)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2332) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
            blurRadius: 32,
            offset: const Offset(0, 12),
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
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                AppStrings.t('signIn', lang),
                style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 12)),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _navigateToLogin(isRegister: true),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.8), width: 1.5),
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                AppStrings.t('createAccount', lang),
                style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin({bool isRegister = false}) async {
    if (isRegister) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
    setState(() {});
  }

  Widget _buildProfileView(ThemeData theme, bool isDark) {
    final user = AuthService.currentUser!;
    final lang = context.read<AppSettingsProvider>().language;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          stretch: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
            centerTitle: true,
            titlePadding: const EdgeInsets.only(bottom: 16),
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
            offset: const Offset(0, -28),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 20)),
              child: Column(
                children: [
                  _buildProfileHero(user, cardColor, lang, theme)
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
                  SizedBox(height: Responsive.spacing(context, 16)),
                  _buildPreferencesSection(theme, cardColor, lang)
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 350.ms)
                      .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                  SizedBox(height: Responsive.spacing(context, 20)),
                  _buildActionsSection(cardColor, lang)
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 350.ms)
                      .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                  SizedBox(height: Responsive.spacing(context, 48)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHero(UserModel user, Color cardColor, String lang, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        top: Responsive.spacing(context, 52),
        left: Responsive.spacing(context, 24),
        right: Responsive.spacing(context, 24),
        bottom: Responsive.spacing(context, 24),
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '؟',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 16)),
          Text(
            user.name,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 22),
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Responsive.spacing(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  user.email,
                  style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: theme.colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (user.phone != null) ...[
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                SizedBox(width: 6),
                Text(
                  user.phone!,
                  style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
          SizedBox(height: 18),
          TextButton.icon(
            onPressed: () {},
            icon: Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
            label: Text(AppStrings.t('editProfile', lang), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(ThemeData theme, Color cardColor, String lang) {
    final settings = context.watch<AppSettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPrefRow(
            icon: Icons.language_rounded,
            title: AppStrings.t('language', lang),
            child: GestureDetector(
              onTap: () => _showLanguageSheet(settings),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.isArabic ? AppStrings.t('arabic', lang) : AppStrings.t('english', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primary),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary, size: 20),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildPrefRow(
            icon: Icons.dark_mode_rounded,
            title: AppStrings.t('darkMode', lang),
            child: Switch.adaptive(
              value: settings.isDarkMode,
              onChanged: (_) => settings.toggleDarkMode(),
              activeTrackColor: AppTheme.primary.withValues(alpha: 0.5),
              activeThumbColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefRow({required IconData icon, required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.primary),
        SizedBox(width: 14),
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

  void _showLanguageSheet(AppSettingsProvider settings) {
    final lang = settings.language;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 24)),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2332) : Colors.white,
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                AppStrings.t('language', lang),
                style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
              ),
              SizedBox(height: 12),
              _buildLangOption('ar', AppStrings.t('arabic', lang), settings),
              _buildLangOption('en', AppStrings.t('english', lang), settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangOption(String value, String label, AppSettingsProvider settings) {
    final isSelected = settings.language == value;
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          settings.setLanguage(value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? AppTheme.primary : theme.colorScheme.onSurfaceVariant, size: 22),
              SizedBox(width: 14),
              Text(label, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsSection(Color cardColor, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 4, bottom: 12),
          child: Text(
            AppStrings.t('quickAccess', lang),
            style: TextStyle(fontSize: Responsive.fontSize(context, 13), fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        _buildActionTile(
          icon: Icons.event_note_rounded,
          title: AppStrings.t('myBookings', lang),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingsScreen())),
          cardColor: cardColor,
        ),
        SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.favorite_rounded,
          title: AppStrings.t('favorites', lang),
          onTap: () {},
          cardColor: cardColor,
        ),
        SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.help_outline_rounded,
          title: AppStrings.t('help', lang),
          onTap: () {},
          cardColor: cardColor,
        ),
        SizedBox(height: 14),
        _buildActionTile(
          icon: Icons.logout_rounded,
          title: AppStrings.t('logout', lang),
          onTap: _logout,
          textColor: Colors.red.shade500,
          iconColor: Colors.red.shade500,
          cardColor: cardColor,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color cardColor,
    Color? textColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final fgColor = textColor ?? theme.colorScheme.onSurface;
    final fgIcon = iconColor ?? AppTheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.03), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: fgIcon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: fgIcon),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: Responsive.fontSize(context, 15), fontWeight: FontWeight.w600, color: fgColor)),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

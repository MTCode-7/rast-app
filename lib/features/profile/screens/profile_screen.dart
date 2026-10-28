import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/screens/register_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart'
    show AuthService, UserModel;
import 'package:rast/core/services/review_prompt_service.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/features/bookings/screens/bookings_screen.dart';
import 'package:rast/features/cart/screens/cart_screen.dart';
import 'package:rast/features/favorites/screens/favorites_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  /// رقم مركز المساعدة (مكالمات وواتساب).
  static const String supportPhoneDisplay = '0503363077';
  static const String supportPhoneWhatsApp = '966540566202';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

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
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      AppStrings.t('logoutConfirm', lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      AppStrings.t('cancel', lang),
                      style: TextStyle(
                        color: RastUi.secondaryText(ctx),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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
      await AnalyticsService.setUserId(null);
      if (mounted) context.read<CartService>().clearLocal();
      setState(() {});
    }
  }

  Future<void> _deleteAccount() async {
    final lang = context.read<AppSettingsProvider>().language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: context.read<AppSettingsProvider>().textDirection,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(AppStrings.t('deleteAccountConfirm', lang)),
          content: Text(AppStrings.t('deleteAccountConfirmMessage', lang)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Row(
                textDirection: TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        AppStrings.t('deleteAccountConfirm', lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      AppStrings.t('cancel', lang),
                      style: TextStyle(
                        color: RastUi.secondaryText(ctx),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Api.auth.deleteAccount();
      } catch (_) {}
      await AuthService.logout();
      if (mounted) {
        context.read<CartService>().clearLocal();
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final theme = Theme.of(context);
    return Directionality(
      textDirection: settings.textDirection,
      child: AuthService.isLoggedIn
          ? _buildProfileView(settings)
          : _buildGuestView(theme, settings),
    );
  }

  Widget _buildGuestView(ThemeData theme, AppSettingsProvider settings) {
    final lang = settings.language;
    return Container(
      decoration: BoxDecoration(color: RastUi.screenSurface(context)),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.spacing(context, 24)),
            child: Column(
              children: [
                const RastLogo(size: 160)
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .scale(begin: const Offset(0.88, 0.88)),
                SizedBox(height: Responsive.spacing(context, 24)),
                Text(
                  AppStrings.t('signInToContinue', lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RastUi.textPurple,
                    fontSize: Responsive.fontSize(context, 23),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 8)),
                Text(
                  AppStrings.t('manageDataSubtitle', lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RastUi.mutedText,
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
                        : RastUi.cardSurface(context),
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
                        child: FilledButton(
                          onPressed: () => _navigateToLogin(),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 54),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: TextStyle(
                              fontSize: Responsive.fontSize(context, 15),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          child: Text(
                            AppStrings.t('signIn', lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 15),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, 12)),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _navigateToLogin(isRegister: true),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 54),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: TextStyle(
                              fontSize: Responsive.fontSize(context, 15),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          child: Text(
                            AppStrings.t('createAccount', lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 15),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
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

  Widget _buildProfileView(AppSettingsProvider settings) {
    final user = AuthService.currentUser!;
    final lang = settings.language;

    return Container(
      color: RastUi.screenSurface(context),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            Responsive.spacing(context, 38),
            Responsive.spacing(context, 18),
            Responsive.spacing(context, 38),
            Responsive.spacing(context, 42),
          ),
          child: Column(
            children: [
              Text(
                AppStrings.t('profile', lang),
                style: TextStyle(
                  color: RastUi.textPurple,
                  fontSize: Responsive.fontSize(context, 20),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 34)),
              _buildProfileHero(user)
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .scale(begin: const Offset(0.92, 0.92)),
              SizedBox(height: Responsive.spacing(context, 42)),
              _buildActionTile(
                icon: Icons.person_outline_rounded,
                title: AppStrings.t('accountDetails', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: () => _showUserDetails(user),
              ),
              _buildActionTile(
                icon: Icons.event_note_rounded,
                title: AppStrings.t('myBookings', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingsScreen(showBackButton: true),
                  ),
                ),
              ),
              _buildActionTile(
                icon: Icons.shopping_cart_outlined,
                title: AppStrings.t('cart', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
              _buildActionTile(
                icon: Icons.favorite_rounded,
                title: AppStrings.t('favorites', lang),
                textColor: Color(0xFF535353),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                ),
                iconColor: RastUi.purple,
              ),
              _buildActionTile(
                icon: Icons.info_outline_rounded,
                title: AppStrings.t('helpCenter', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: _showHelpCenter,
              ),
              _buildActionTile(
                icon: Icons.privacy_tip_outlined,
                title: AppStrings.t('privacyPolicy', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: _openPrivacyPolicy,
              ),
              _buildActionTile(
                icon: Icons.star_rate_rounded,
                title: AppStrings.t('rateApp', lang),
                textColor: Color(0xFF535353),
                iconColor: Colors.amber,
                onTap: ReviewPromptService.openStore,
              ),
              _buildActionTile(
                icon: Icons.verified_outlined,
                title: AppStrings.t('aboutApp', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: _showAboutApp,
              ),
              _buildActionTile(
                icon: Icons.manage_accounts_outlined,
                title: AppStrings.t('settings', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: () => _showSettingsSheet(settings),
              ),
              _buildActionTile(
                icon: Icons.credit_card_rounded,
                title: AppStrings.t('paymentMethods', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: _showPaymentMethods,
              ),
              _buildActionTile(
                icon: Icons.password_rounded,
                title: AppStrings.t('changePassword', lang),
                textColor: Color(0xFF535353),
                iconColor: Color(0xFF535353),
                onTap: _showChangePasswordInfo,
              ),
              _buildActionTile(
                icon: Icons.delete_forever_rounded,
                title: AppStrings.t('deleteAccount', lang),
                onTap: _deleteAccount,
                iconColor: Colors.red.shade600,
                textColor: Colors.red.shade600,
              ),
              _buildActionTile(
                icon: Icons.logout_rounded,
                title: AppStrings.t('logout', lang),
                onTap: _logout,
                iconColor: RastUi.purple,
                showDivider: false,
                textColor: Color(0xFF535353),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(UserModel user) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: RastUi.subtleFill(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.name.trim().isNotEmpty
                      ? user.name.trim().characters.first.toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: RastUi.textPurple,
                    fontSize: Responsive.fontSize(context, 48),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (user.name.trim().isNotEmpty) ...[
          SizedBox(height: Responsive.spacing(context, 14)),
          Text(
            user.name.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: RastUi.textPurple,
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (user.email.trim().isNotEmpty ||
            (user.phone?.trim().isNotEmpty ?? false))
          Text(
            user.email.trim().isNotEmpty
                ? user.email.trim()
                : user.phone!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF535353),
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
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
      child: _buildPrefRow(
        icon: Icons.language_rounded,
        title: AppStrings.t('language', lang),
        child: InkWell(
          onTap: () => _showLanguageSheet(settings),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    bool showDivider = true,
  }) {
    final fgText = textColor ?? RastUi.secondaryText(context);
    final fgIcon = iconColor ?? RastUi.purple;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.spacing(context, 13),
              ),
              child: Row(
                children: [
                  Icon(icon, color: fgIcon, size: 23),
                  SizedBox(width: Responsive.spacing(context, 12)),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: fgText,
                        fontWeight: FontWeight.w500,
                        fontSize: Responsive.fontSize(context, 17),
                      ),
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 24,
                    color: const Color(0xFF535353),
                  ),
                ],
              ),
            ),
            if (showDivider)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F1F3)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchSupportCall() async {
    final uri = Uri.parse('tel:${ProfileScreen.supportPhoneDisplay}');
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')));
      return;
    }
    await launchUrl(uri);
  }

  Future<void> _launchSupportWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/${ProfileScreen.supportPhoneWhatsApp}',
    );
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showHelpCenter() {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(ctx, 20),
            vertical: Responsive.spacing(ctx, 24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(ctx).size.height * 0.82,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: RastUi.cardSurface(ctx),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.spacing(ctx, 22)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TOP ICON
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: RastUi.brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: settings.primaryColor.withValues(
                              alpha: 0.22,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),

                    SizedBox(height: Responsive.spacing(ctx, 16)),

                    // TITLE
                    Text(
                      AppStrings.t('helpCenter', lang),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RastUi.textPurple,
                        fontSize: Responsive.fontSize(ctx, 20),
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: Responsive.spacing(ctx, 10)),

                    // DESCRIPTION
                    Text(
                      AppStrings.t('helpCenterMessage', lang),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: RastUi.secondaryText(ctx),
                        fontSize: Responsive.fontSize(ctx, 13),
                        fontWeight: FontWeight.w400,
                        height: 1.55,
                      ),
                    ),

                    SizedBox(height: Responsive.spacing(ctx, 20)),

                    // PHONE CARD
                    // PHONE CARD
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.spacing(ctx, 16),
                        vertical: Responsive.spacing(ctx, 14),
                      ),
                      decoration: BoxDecoration(
                        color: RastUi.subtleFill(ctx),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: RastUi.softBorder(ctx)),
                      ),
                      child: Row(
                        textDirection: settings.textDirection,
                        children: [
                          // PHONE ICON
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: RastUi.purple.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.phone_in_talk_rounded,
                              color: RastUi.purple,
                              size: 21,
                            ),
                          ),

                          SizedBox(width: Responsive.spacing(ctx, 12)),

                          // PHONE NUMBER
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                ProfileScreen.supportPhoneDisplay,
                                textAlign: TextAlign.start,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(ctx, 18),
                                  fontWeight: FontWeight.w800,
                                  color: RastUi.primaryText(ctx),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: Responsive.spacing(ctx, 8)),

                          // COPY BUTTON
                          Material(
                            color: RastUi.purple.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                await Clipboard.setData(
                                  const ClipboardData(
                                    text: ProfileScreen.supportPhoneDisplay,
                                  ),
                                );

                                if (!ctx.mounted) return;

                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(AppStrings.t('copied', lang)),
                                  ),
                                );
                              },
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.copy_rounded,
                                  color: RastUi.purple,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.spacing(ctx, 20)),

                    // WHATSAPP BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _launchSupportWhatsApp();
                        },
                        icon: const Icon(Icons.chat_rounded, size: 20),
                        label: Flexible(
                          child: Text(
                            AppStrings.t('whatsapp', lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.spacing(ctx, 12)),

                    // CALL BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _launchSupportCall();
                        },
                        icon: const Icon(Icons.phone_rounded, size: 20),
                        label: Flexible(
                          child: Text(
                            AppStrings.t('call', lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RastUi.purple,
                          backgroundColor: RastUi.cardSurface(ctx),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          side: BorderSide(color: RastUi.softBorder(ctx)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.spacing(ctx, 10)),

                    // CLOSE
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        AppStrings.t('close', lang),
                        style: TextStyle(
                          color: RastUi.secondaryText(ctx),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    const url = 'https://rast-labs.com/privacy-policy';
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح سياسة الخصوصية')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showAboutApp() {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(AppStrings.t('aboutApp', lang)),
          content: SingleChildScrollView(
            child: Text(
              AppStrings.t('aboutAppDescription', lang),
              style: TextStyle(color: RastUi.secondaryText(ctx)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.t('close', lang)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openPrivacyPolicy();
              },
              child: Text(AppStrings.t('privacyPolicy', lang)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethods() {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(AppStrings.t('paymentMethods', lang)),
          content: SingleChildScrollView(
            child: Text(
              AppStrings.t('paymentMethodsDescription', lang),
              style: TextStyle(color: RastUi.secondaryText(ctx)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.t('close', lang)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordInfo() {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;

    final current = TextEditingController();
    final newPwd = TextEditingController();
    final confirm = TextEditingController();

    bool obscure1 = true;
    bool obscure2 = true;
    bool obscure3 = true;
    bool loading = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: settings.textDirection,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(Responsive.spacing(context, 22)),
                decoration: BoxDecoration(
                  color: RastUi.cardSurface(context),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          gradient: RastUi.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: settings.primaryColor.withValues(
                                alpha: 0.22,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      SizedBox(height: Responsive.spacing(context, 14)),

                      Text(
                        AppStrings.t('changePassword', lang),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RastUi.textPurple,
                          fontSize: Responsive.fontSize(context, 20),
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      SizedBox(height: Responsive.spacing(context, 24)),

                      _changePasswordField(
                        controller: current,
                        label: AppStrings.t('currentPassword', lang),
                        obscure: obscure1,
                        onToggle: () {
                          setDialogState(() => obscure1 = !obscure1);
                        },
                      ),

                      const SizedBox(height: 14),

                      _changePasswordField(
                        controller: newPwd,
                        label: AppStrings.t('newPassword', lang),
                        obscure: obscure2,
                        onToggle: () {
                          setDialogState(() => obscure2 = !obscure2);
                        },
                      ),

                      const SizedBox(height: 14),

                      _changePasswordField(
                        controller: confirm,
                        label: AppStrings.t('confirmNewPassword', lang),
                        obscure: obscure3,
                        onToggle: () {
                          setDialogState(() => obscure3 = !obscure3);
                        },
                      ),

                      SizedBox(height: Responsive.spacing(context, 26)),

                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: RastUi.brandGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: settings.primaryColor.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: FilledButton(
                                  onPressed: loading
                                      ? null
                                      : () async {
                                          final c = current.text.trim();
                                          final n = newPwd.text;
                                          final cf = confirm.text;

                                          if (c.isEmpty ||
                                              n.isEmpty ||
                                              cf.isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppStrings.t(
                                                    'fillAllFields',
                                                    lang,
                                                  ),
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (n.length < 8) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppStrings.t(
                                                    'passwordMinLength',
                                                    lang,
                                                  ),
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (n != cf) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppStrings.t(
                                                    'passwordConfirmationMismatch',
                                                    lang,
                                                  ),
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          setDialogState(() => loading = true);

                                          try {
                                            await Api.auth.updatePassword(
                                              currentPassword: c,
                                              newPassword: n,
                                              newPasswordConfirmation: cf,
                                            );

                                            if (ctx.mounted) {
                                              FocusScope.of(ctx).unfocus();
                                              Navigator.pop(ctx);
                                            }

                                            if (!mounted) return;

                                            ScaffoldMessenger.of(
                                              this.context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppStrings.t(
                                                    'passwordUpdated',
                                                    lang,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } on ApiException catch (e) {
                                            if (!ctx.mounted) return;

                                            setDialogState(
                                              () => loading = false,
                                            );

                                            ScaffoldMessenger.of(
                                              ctx,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(e.message),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!ctx.mounted) return;

                                            setDialogState(
                                              () => loading = false,
                                            );

                                            ScaffoldMessenger.of(
                                              ctx,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e
                                                      .toString()
                                                      .split('\n')
                                                      .first,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          AppStrings.t('save', lang),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: OutlinedButton(
                                onPressed: loading
                                    ? null
                                    : () {
                                        FocusScope.of(ctx).unfocus();
                                        Navigator.pop(ctx);
                                      },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  side: BorderSide(
                                    color: RastUi.softBorder(context),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  AppStrings.t('cancel', lang),
                                  style: TextStyle(
                                    color: RastUi.secondaryText(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _changePasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: RastUi.subtleFill(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: RastUi.purple,
          size: 20,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: RastUi.secondaryText(context),
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: RastUi.softBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: RastUi.softBorder(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: context.read<AppSettingsProvider>().primaryColor,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  void _showUserDetails(UserModel user) {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.spacing(context, 22)),
            decoration: BoxDecoration(
              color: RastUi.cardSurface(context),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: RastUi.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: settings.primaryColor.withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                SizedBox(height: Responsive.spacing(context, 14)),

                // Title
                Text(
                  AppStrings.t('accountDetails', lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RastUi.textPurple,
                    fontSize: Responsive.fontSize(context, 20),
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: Responsive.spacing(context, 22)),

                // Name
                if (user.name.trim().isNotEmpty)
                  _buildUserDetailRow(
                    icon: Icons.person_outline_rounded,
                    label: AppStrings.t('fullName', lang),
                    value: user.name.trim(),
                  ),

                if (user.name.trim().isNotEmpty)
                  SizedBox(height: Responsive.spacing(context, 12)),

                // Email
                if (user.email.trim().isNotEmpty)
                  _buildUserDetailRow(
                    icon: Icons.email_outlined,
                    label: AppStrings.t('email', lang),
                    value: user.email.trim(),
                    forceLtr: true,
                  ),

                if (user.email.trim().isNotEmpty &&
                    (user.phone?.trim().isNotEmpty ?? false))
                  SizedBox(height: Responsive.spacing(context, 12)),

                // Phone
                if (user.phone?.trim().isNotEmpty ?? false)
                  _buildUserDetailRow(
                    icon: Icons.phone_outlined,
                    label: AppStrings.t('phone', lang),
                    value: user.phone!.trim(),
                    forceLtr: true,
                  ),

                SizedBox(height: Responsive.spacing(context, 22)),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: settings.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.spacing(context, 13),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppStrings.t('close', lang),
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool forceLtr = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 14),
        vertical: Responsive.spacing(context, 12),
      ),
      decoration: BoxDecoration(
        color: RastUi.subtleFill(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RastUi.softBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RastUi.purple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: RastUi.purple),
          ),

          SizedBox(width: Responsive.spacing(context, 12)),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: RastUi.secondaryText(context),
                    fontSize: Responsive.fontSize(context, 10),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 3),

                Directionality(
                  textDirection: forceLtr
                      ? TextDirection.ltr
                      : Directionality.of(context),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RastUi.primaryText(context),
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(AppSettingsProvider settings) {
    final lang = settings.language;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 18)),
          decoration: BoxDecoration(
            color: RastUi.cardSurface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _buildPreferencesCard(settings, lang),
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

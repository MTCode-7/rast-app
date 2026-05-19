import 'package:flutter/material.dart';
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
import 'package:rast/features/bookings/screens/bookings_screen.dart';
import 'package:rast/features/favorites/screens/favorites_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  /// رقم مركز المساعدة (مكالمات وواتساب).
  static const String supportPhoneDisplay = '0540566202';
  static const String supportPhoneWhatsApp = '966540566202';

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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.t('cancel', lang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(AppStrings.t('deleteAccountConfirm', lang)),
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
      if (mounted) setState(() {});
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
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: RastUi.blue,
                      ),
                    ),
                  ),
                  Text(
                    AppStrings.t('profile', lang),
                    style: TextStyle(
                      color: RastUi.textPurple,
                      fontSize: Responsive.fontSize(context, 20),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.spacing(context, 34)),
              _buildProfileHero(user)
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .scale(begin: const Offset(0.92, 0.92)),
              SizedBox(height: Responsive.spacing(context, 42)),
              _buildActionTile(
                icon: Icons.person_outline_rounded,
                title: 'تعديل الملف الشخصي',
                onTap: () => _showUserDetails(user),
              ),
              _buildActionTile(
                icon: Icons.event_note_rounded,
                title: AppStrings.t('myBookings', lang),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingsScreen()),
                ),
              ),
              _buildActionTile(
                icon: Icons.favorite_rounded,
                title: AppStrings.t('favorites', lang),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                ),
                iconColor: RastUi.purple,
              ),
              _buildActionTile(
                icon: Icons.info_outline_rounded,
                title: 'مركز المساعدة',
                onTap: _showHelpCenter,
              ),
              _buildActionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'سياسة الخصوصية',
                onTap: _openPrivacyPolicy,
              ),
              _buildActionTile(
                icon: Icons.verified_outlined,
                title: 'حول التطبيق',
                onTap: _showAboutApp,
              ),
              _buildActionTile(
                icon: Icons.manage_accounts_outlined,
                title: AppStrings.t('settings', lang),
                onTap: () => _showSettingsSheet(settings),
              ),
              _buildActionTile(
                icon: Icons.credit_card_rounded,
                title: 'طرق الدفع',
                onTap: _showPaymentMethods,
              ),
              _buildActionTile(
                icon: Icons.password_rounded,
                title: 'تغيير كلمة المرور',
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
              child: Icon(
                Icons.person_rounded,
                color: const Color(0xFFC9D0D8),
                size: Responsive.fontSize(context, 78),
              ),
            ),
            PositionedDirectional(
              end: 8,
              bottom: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RastUi.brandGradient,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: Colors.white,
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
              color: RastUi.mutedText,
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
                  const Icon(
                    Icons.chevron_left_rounded,
                    size: 24,
                    color: Color(0xFFD4D7DE),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showHelpCenter() {
    final lang = context.read<AppSettingsProvider>().language;
    final isAr = lang == 'ar';
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isAr ? 'مركز المساعدة' : 'Help Center'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isAr
                    ? 'للمساعدة في الحجز أو الدفع أو استخدام التطبيق، تواصل معنا:'
                    : 'For help with booking, payment, or the app, contact us:',
                style: TextStyle(color: RastUi.secondaryText(ctx)),
              ),
              const SizedBox(height: 16),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  ProfileScreen.supportPhoneDisplay,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: RastUi.primaryText(ctx),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _launchSupportWhatsApp();
                },
                icon: const Icon(Icons.chat_rounded),
                label: Text(isAr ? 'واتساب' : 'WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _launchSupportCall();
                },
                icon: const Icon(Icons.phone_rounded),
                label: Text(isAr ? 'اتصال' : 'Call'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إغلاق' : 'Close'),
          ),
        ],
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
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('حول التطبيق'),
        content: SingleChildScrollView(
          child: Text(
            'RAST هو تطبيق يتيح للمستخدمين العثور على المختبرات الطبية وحجز التحاليل بسهولة.\n\nيمكنك الاطلاع على سياسة الخصوصية عبر: https://rast-labs.com/privacy-policy',
            style: TextStyle(color: RastUi.secondaryText(ctx)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openPrivacyPolicy();
            },
            child: const Text('سياسة الخصوصية'),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethods() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('طرق الدفع'),
        content: SingleChildScrollView(
          child: Text(
            'قد تختلف طرق الدفع حسب المختبر. عند تأكيد الحجز ستظهر الرسوم وطرق الدفع ضمن ملخص الطلب قبل التنفيذ.',
            style: TextStyle(color: RastUi.secondaryText(ctx)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordInfo() {
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
            textDirection:
                context.read<AppSettingsProvider>().textDirection,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('تغيير كلمة المرور'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: current,
                      obscureText: obscure1,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure1
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => obscure1 = !obscure1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPwd,
                      obscureText: obscure2,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure2
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => obscure2 = !obscure2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirm,
                      obscureText: obscure3,
                      decoration: InputDecoration(
                        labelText: 'تأكيد الجديدة',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure3
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => obscure3 = !obscure3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final c = current.text;
                          final n = newPwd.text;
                          final cf = confirm.text;
                          if (c.isEmpty || n.isEmpty || cf.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('املأ جميع الحقول'),
                              ),
                            );
                            return;
                          }
                          if (n.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'كلمة المرور الجديدة 8 أحرف على الأقل',
                                ),
                              ),
                            );
                            return;
                          }
                          if (n != cf) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('التأكيد لا يطابق الجديدة'),
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
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تحديث كلمة المرور'),
                              ),
                            );
                          } on ApiException catch (e) {
                            setDialogState(() => loading = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => loading = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().split('\n').first,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      current.dispose();
      newPwd.dispose();
      confirm.dispose();
    });
  }

  void _showUserDetails(UserModel user) {
    final details = [
      if (user.name.trim().isNotEmpty) user.name.trim(),
      if (user.email.trim().isNotEmpty) user.email.trim(),
      if (user.phone?.trim().isNotEmpty ?? false) user.phone!.trim(),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: context.read<AppSettingsProvider>().textDirection,
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 22)),
          decoration: BoxDecoration(
            color: RastUi.cardSurface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'بيانات الحساب',
                style: TextStyle(
                  color: RastUi.textPurple,
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 14)),
              for (final item in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item,
                    style: TextStyle(color: RastUi.secondaryText(context)),
                  ),
                ),
            ],
          ),
        ),
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

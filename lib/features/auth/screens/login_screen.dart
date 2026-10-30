import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/screens/forgot_password_screen.dart';
import 'package:rast/features/auth/screens/register_screen.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/chat/screens/chat_screen.dart';

import '../../../app/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('login');
  }

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  String _normalizePhoneForApi(String value) {
    final phone = value.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('00')) return phone.substring(2);
    if (phone.startsWith('0')) return '966${phone.substring(1)}';
    if (phone.startsWith('966')) return phone;
    return phone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = await Api.auth.login(
        _normalizePhoneForApi(_phoneController.text),
        _passwordController.text,
      );
      final token = data['token']?.toString();
      final userData = data['user'] ?? data;
      if (token == null) throw ApiException('Login token was not received');

      final user = UserModel.fromJson(
        userData is Map<String, dynamic> ? userData : <String, dynamic>{},
      );
      await AuthService.login(token, user);
      await AnalyticsService.setUserId(user.id.toString(), email: user.email, phone: user.phone);
      await AnalyticsService.logLogin();
      if (!mounted) return;
      context.read<CartService>().refresh(silent: true);

      setState(() => _isLoading = false);
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final lang = context.read<AppSettingsProvider>().language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('SocketException')
                ? AppStrings.t('checkConnection', lang)
                : e.toString(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    final textDirection =
    lang == 'en' ? TextDirection.ltr : TextDirection.rtl;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: RastUi.screenSurface(context),
        body: Stack(
          children: [
            // Header background
            Container(
              height: 240,
              decoration: const BoxDecoration(
                gradient: RastUi.headerGradient,
              ),
            ),

            // Top title
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: 12,
                    start: 20,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.t(
                          'loginTopTitle',
                          lang,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),

            // Floating form
            Positioned.fill(
              top: 135,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.spacing(context, 16),
                  0,
                  Responsive.spacing(context, 16),
                  Responsive.spacing(context, 90),
                ),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.spacing(context, 20),
                    Responsive.spacing(context, 20),
                    Responsive.spacing(context, 20),
                    Responsive.spacing(context, 18),
                  ),
                  decoration: BoxDecoration(
                    color: RastUi.screenSurface(context),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.32),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _authHeader(
                        title: AppStrings.t(
                          'loginTitle',
                          lang,
                        ),
                        subtitle: AppStrings.t(
                          'loginSubtitle',
                          lang,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 420.ms)
                          .slideY(begin: 0.1, end: 0),

                      SizedBox(
                        height: Responsive.spacing(context, 24),
                      ),

                      _buildCard(
                        context,
                        isDark,
                        lang,
                      )
                          .animate()
                          .fadeIn(
                        delay: 120.ms,
                        duration: 420.ms,
                      )
                          .slideY(begin: 0.07, end: 0),

                      SizedBox(
                        height: Responsive.spacing(context, 14),
                      ),

                      _buildBottomLink(lang),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppStrings.t("continueAs", settings.language),
                            style: TextStyle(
                              color: Color(0xFF535353),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const MainScaffold(),
                                ),
                                    (route) => false,
                              );
                            },
                            child: Text(
                              AppStrings.t(
                                'Guest',
                                settings.language,
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: Responsive.fontSize(context, 15),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            RastSupportBubble(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, bool isDark, String lang) {
    final primary = context.watch<AppSettingsProvider>().primaryColor;
    final fill = isDark ? const Color(0xFF0F172A) : Colors.white;
    return Container(
      padding: EdgeInsets.zero,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: AppStrings.t(
                  'phoneNumber',
                  lang,
                ),
                icon: Icons.phone_iphone_rounded,
              ),
              validator: (v) {
                final phone = v?.trim() ?? '';

                if (phone.isEmpty) {
                  return AppStrings.t(
                    'phoneRequired',
                    lang,
                  );
                }

                if (phone.length < 9) {
                  return AppStrings.t(
                    'phoneInvalid',
                    lang,
                  );
                }

                return null;
              },
            ),
            SizedBox(height: Responsive.spacing(context, 12)),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: AppStrings.t('password', lang),
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? AppStrings.t('passwordRequired', lang)
                  : null,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                ),
                child: Text(AppStrings.t('forgotPassword', lang)),
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 26)),
            GradientFilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.spacing(context, 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      AppStrings.t('loginButton', lang),
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomLink(String lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.t('noAccount', lang),
          style: const TextStyle(color: Color(0xFF535353), fontSize: 12),
        ),
        TextButton(
          onPressed: () async {
            final v = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
            if (v == true) widget.onSuccess?.call();
          },
          child: Text(
            AppStrings.t('createAccount', lang),
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _authHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RastUi.blue,
            fontSize: Responsive.fontSize(
              context,
              21,
            ),
            fontWeight: FontWeight.w800,
          ),
        ),

        SizedBox(
          height: Responsive.spacing(context, 4),
        ),

        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RastUi.textPurple,
            fontSize: Responsive.fontSize(
              context,
              12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  InputDecoration _fieldDecoration(
      Color fill, {
        required Color primary,
        required String label,
        required String hint,
        required IconData icon,
        Widget? suffix,
      }) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      hintText: hint,

      prefixIcon: Icon(
        icon,
        color: primary.withValues(alpha: 0.85),
        size: 19,
      ),

      suffixIcon: suffix,

      filled: true,
      fillColor: fill,

      hintStyle: TextStyle(
        fontSize: Responsive.fontSize(
          context,
          12,
        ),
      ),

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(
          color: Color(0xFFD7D4DA),
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(
          color: Color(0xFFD7D4DA),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: primary,
          width: 2,
        ),
      ),
    );
  }

}

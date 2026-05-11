import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/app_assets.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/screens/forgot_password_screen.dart';
import 'package:rast/features/auth/screens/register_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/chat/screens/chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      if (!mounted) return;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastUi.screenSurface(context),
        body: Stack(
          children: [
            Container(
              height: 132,
              decoration: const BoxDecoration(gradient: RastUi.headerGradient),
            ),
            SafeArea(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            AppAssets.appIcon,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              color: Colors.white.withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.medical_services_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              top: 108,
              child: Container(
                decoration: BoxDecoration(
                  color: RastUi.screenSurface(context),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.spacing(context, 24),
                    Responsive.spacing(context, 12),
                    Responsive.spacing(context, 24),
                    Responsive.spacing(context, 90),
                  ),
                  child: Column(
                    children: [
                      _authHeader(
                            icon: Icons.lock_open_rounded,
                            title: AppStrings.t('loginTitle', lang),
                            subtitle: AppStrings.t('loginSubtitle', lang),
                          )
                          .animate()
                          .fadeIn(duration: 420.ms)
                          .slideY(begin: 0.1, end: 0),
                      SizedBox(height: Responsive.spacing(context, 24)),
                      _buildCard(context, isDark, lang)
                          .animate()
                          .fadeIn(delay: 120.ms, duration: 420.ms)
                          .slideY(begin: 0.07, end: 0),
                      SizedBox(height: Responsive.spacing(context, 12)),
                      _buildBottomLink(lang),
                    ],
                  ),
                ),
              ),
            ),
            RastSupportBubble(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
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
                hint: 'رقم الجوال',
                icon: Icons.phone_iphone_rounded,
              ),
              validator: (v) {
                final phone = v?.trim() ?? '';
                if (phone.isEmpty) {
                  return 'رقم الجوال مطلوب';
                }
                if (phone.length < 9) {
                  return 'رقم الجوال غير صحيح';
                }
                return null;
              },
            ),
            SizedBox(height: Responsive.spacing(context, 20)),
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
              alignment: Alignment.centerLeft,
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
            SizedBox(height: Responsive.spacing(context, 8)),
            GradientFilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.spacing(context, 15),
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
                        fontSize: Responsive.fontSize(context, 16),
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
          style: const TextStyle(color: Color(0xFFBDB9C3), fontSize: 12),
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
    required IconData icon,
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
            fontSize: Responsive.fontSize(context, 26),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 6)),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RastUi.textPurple,
            fontSize: Responsive.fontSize(context, 14),
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 28)),
        _buildLockIllustration(),
      ],
    );
  }

  Widget _buildLockIllustration() {
    return SizedBox(
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(top: 6, child: _dot(10, RastUi.purple)),
          Positioned(right: 42, top: 28, child: _dot(24, RastUi.purple)),
          Positioned(left: 44, bottom: 32, child: _dot(20, RastUi.blue)),
          Positioned(right: 52, bottom: 38, child: _dot(10, Colors.black54)),
          Positioned(
            left: 28,
            top: 70,
            child: _dot(10, const Color(0xFFE8E4E2)),
          ),
          Container(
            width: 60,
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [RastUi.blue, RastUi.purple],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: RastUi.softShadow,
            ),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.contain,
                child: RastLogo(size: 44, light: true),
              ),
            ),
          ),
          Positioned(
            top: 48,
            child: Container(
              width: 34,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: RastUi.blue, width: 5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
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
      prefixIcon: Icon(icon, color: primary.withValues(alpha: 0.85)),
      suffixIcon: suffix,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Color(0xFFD7D4DA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Color(0xFFD7D4DA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    );
  }
}

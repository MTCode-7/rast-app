import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/features/auth/screens/forgot_password_screen.dart';
import 'package:rast/features/auth/screens/register_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = await Api.auth.login(
        _emailController.text.trim(),
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
        body: Container(
          decoration: BoxDecoration(gradient: settings.primaryGradient),
          child: Stack(
            children: [
              Positioned(top: -70, right: -70, child: _deco(190)),
              Positioned(bottom: 90, left: -65, child: _deco(160)),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(Responsive.spacing(context, 20)),
                  child: Column(
                    children: [
                      SizedBox(height: Responsive.spacing(context, 16)),
                      _authHeader(
                            icon: Icons.lock_open_rounded,
                            title: AppStrings.t('loginTitle', lang),
                            subtitle: AppStrings.t('loginSubtitle', lang),
                          )
                          .animate()
                          .fadeIn(duration: 420.ms)
                          .slideY(begin: 0.1, end: 0),
                      SizedBox(height: Responsive.spacing(context, 22)),
                      _buildCard(context, isDark, lang)
                          .animate()
                          .fadeIn(delay: 120.ms, duration: 420.ms)
                          .slideY(begin: 0.07, end: 0),
                      SizedBox(height: Responsive.spacing(context, 16)),
                      _buildBottomLink(lang),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, bool isDark, String lang) {
    final primary = context.watch<AppSettingsProvider>().primaryColor;
    final fill = isDark
        ? const Color(0xFF0F172A)
        : AppTheme.surfaceVariant.withValues(alpha: 0.45);
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 22)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162033) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('loginButton', lang),
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 18)),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: AppStrings.t('email', lang),
                hint: AppStrings.t('emailHint', lang),
                icon: Icons.email_outlined,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return AppStrings.t('emailRequired', lang);
                }
                if (!v.contains('@')) {
                  return AppStrings.t('emailInvalid', lang);
                }
                return null;
              },
            ),
            SizedBox(height: Responsive.spacing(context, 14)),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: AppStrings.t('password', lang),
                hint: AppStrings.t('passwordHint', lang),
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
                  borderRadius: BorderRadius.circular(16),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppStrings.t('noAccount', lang),
            style: const TextStyle(color: Colors.white),
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
      ),
    );
  }

  Widget _authHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 52, color: Colors.white),
        ),
        SizedBox(height: Responsive.spacing(context, 16)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: Responsive.fontSize(context, 26),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 6)),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: Responsive.fontSize(context, 14),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(
    Color fill, {
    required Color primary,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primary.withValues(alpha: 0.85)),
      suffixIcon: suffix,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    );
  }

  Widget _deco(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}

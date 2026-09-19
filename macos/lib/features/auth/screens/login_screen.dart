import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/auth/screens/register_screen.dart';
import 'package:rast/features/auth/screens/forgot_password_screen.dart';

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
      final data = await Api.auth.login(_emailController.text.trim(), _passwordController.text);
      final token = data['token']?.toString();
      final userData = data['user'] ?? data;
      if (token == null) throw ApiException('لم يتم استلام رمز الدخول');
      final user = UserModel.fromJson(userData is Map<String, dynamic> ? userData : <String, dynamic>{});
      await AuthService.login(token, user);
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains('SocketException') ? AppStrings.t('checkConnection', context.read<AppSettingsProvider>().language) : e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
            Positioned(top: -60, right: -60, child: _buildDecoCircle(180)),
            Positioned(bottom: 80, left: -50, child: _buildDecoCircle(140)),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.spacing(context, 24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: Responsive.spacing(context, 32)),
                    _buildHeader().animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                    SizedBox(height: Responsive.spacing(context, 36)),
                    _buildFormCard().animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                    SizedBox(height: Responsive.spacing(context, 20)),
                    _buildRegisterLink().animate().fadeIn(delay: 250.ms),
                    SizedBox(height: Responsive.spacing(context, 24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecoCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }

  Widget _buildHeader() {
    final lang = context.watch<AppSettingsProvider>().language;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.medical_services_rounded, size: 52, color: Colors.white),
        ),
        SizedBox(height: Responsive.spacing(context, 22)),
        Text(
          AppStrings.t('loginTitle', lang),
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 28),
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          AppStrings.t('loginSubtitle', lang),
          style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: Colors.white.withValues(alpha: 0.9)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<AppSettingsProvider>().language;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 26),
        vertical: Responsive.spacing(context, 28),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.login_rounded, color: AppTheme.primary, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  AppStrings.t('loginButton', lang),
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.spacing(context, 24)),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: InputDecoration(
                labelText: AppStrings.t('email', context.watch<AppSettingsProvider>().language),
                hintText: AppStrings.t('emailHint', context.watch<AppSettingsProvider>().language),
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary.withValues(alpha: 0.8)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant.withValues(alpha: 0.4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
              ),
              validator: (v) {
                final l = context.read<AppSettingsProvider>().language;
                if (v == null || v.isEmpty) return AppStrings.t('emailRequired', l);
                if (!v.contains('@')) return AppStrings.t('emailInvalid', l);
                return null;
              },
            ),
            SizedBox(height: Responsive.spacing(context, 20)),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: InputDecoration(
                labelText: AppStrings.t('password', context.watch<AppSettingsProvider>().language),
                hintText: AppStrings.t('passwordHint', context.watch<AppSettingsProvider>().language),
                prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.primary.withValues(alpha: 0.8)),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant.withValues(alpha: 0.4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
              ),
              validator: (v) => (v == null || v.isEmpty) ? AppStrings.t('passwordRequired', context.read<AppSettingsProvider>().language) : null,
            ),
            SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  foregroundColor: AppTheme.primary,
                ),
                child: Text(
                  AppStrings.t('forgotPassword', context.watch<AppSettingsProvider>().language),
                  style: TextStyle(fontSize: Responsive.fontSize(context, 13), fontWeight: FontWeight.w500),
                ),
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 20)),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 22),
                        SizedBox(width: 10),
                        Text(AppStrings.t('loginButton', context.watch<AppSettingsProvider>().language), style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(AppStrings.t('noAccount', context.watch<AppSettingsProvider>().language), style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: Responsive.fontSize(context, 14))),
          TextButton(
            onPressed: () async {
              final v = await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
              if (v == true) widget.onSuccess?.call();
            },
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: Text(AppStrings.t('createAccount', context.watch<AppSettingsProvider>().language), style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w700, fontSize: Responsive.fontSize(context, 15))),
          ),
        ],
      ),
    );
  }
}

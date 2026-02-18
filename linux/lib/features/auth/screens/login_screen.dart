import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains('SocketException') ? 'تحقق من اتصال الإنترنت' : e.toString())));
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
          ),
          child: Icon(Icons.medical_services_rounded, size: 48, color: Colors.white.withValues(alpha: 0.95)),
        ),
        SizedBox(height: Responsive.spacing(context, 20)),
        Text(
          'مرحباً بعودتك',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 26),
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6),
        Text(
          'سجّل الدخول لمتابعة حجوزاتك',
          style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: Colors.white.withValues(alpha: 0.88)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 26)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                hintText: 'example@email.com',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary.withValues(alpha: 0.8)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.primary, width: 1.5)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أدخل البريد الإلكتروني';
                if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                return null;
              },
            ),
            SizedBox(height: Responsive.spacing(context, 18)),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                hintText: '••••••••',
                prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.primary.withValues(alpha: 0.8)),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.primary, width: 1.5)),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: Text('نسيت كلمة المرور؟', style: TextStyle(color: AppTheme.primary, fontSize: Responsive.fontSize(context, 13), fontWeight: FontWeight.w500)),
              ),
            ),
            SizedBox(height: 8),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('تسجيل الدخول', style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('ليس لديك حساب؟ ', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: Responsive.fontSize(context, 14))),
        TextButton(
          onPressed: () async {
            final v = await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
            if (v == true) widget.onSuccess?.call();
          },
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text('إنشاء حساب', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: Responsive.fontSize(context, 15))),
        ),
      ],
    );
  }
}

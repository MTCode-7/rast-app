import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/features/auth/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = await Api.auth.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );
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
                gradient: AppTheme.primaryGradient,
              ),
            ),
            Positioned(top: -80, left: -60, child: _buildDecoCircle(200)),
            Positioned(bottom: 120, right: -70, child: _buildDecoCircle(160)),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.spacing(context, 24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: Responsive.spacing(context, 28)),
                    _buildHeader().animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                    SizedBox(height: Responsive.spacing(context, 28)),
                    _buildFormCard().animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                    SizedBox(height: Responsive.spacing(context, 20)),
                    _buildLoginLink().animate().fadeIn(delay: 200.ms),
                    SizedBox(height: Responsive.spacing(context, 28)),
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
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Icon(Icons.person_add_rounded, size: 52, color: Colors.white),
        ),
        SizedBox(height: Responsive.spacing(context, 22)),
        Text(
          'إنشاء حساب جديد',
          style: TextStyle(fontSize: Responsive.fontSize(context, 28), fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.4),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'انضم إلينا واستفد من خدماتنا',
          style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: Colors.white.withValues(alpha: 0.9)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant.withValues(alpha: 0.4);
    InputDecoration inputDecoration(String label, String hint, IconData icon, {Widget? suffix}) => InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primary.withValues(alpha: 0.8)),
          suffixIcon: suffix,
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
        );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 24), vertical: Responsive.spacing(context, 26)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08), blurRadius: 32, offset: const Offset(0, 14)),
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 6)),
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
                  child: Icon(Icons.person_add_rounded, color: AppTheme.primary, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'البيانات المطلوبة',
                  style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
            SizedBox(height: Responsive.spacing(context, 22)),
            _sectionLabel('البيانات الشخصية'),
            SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: inputDecoration('الاسم الكامل', 'أدخل اسمك', Icons.person_outline_rounded),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
            ),
            SizedBox(height: Responsive.spacing(context, 18)),
            _sectionLabel('معلومات التواصل'),
            SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: inputDecoration('البريد الإلكتروني', 'example@email.com', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أدخل البريد الإلكتروني';
                if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                return null;
              },
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: inputDecoration('رقم الجوال', '05xxxxxxxx', Icons.phone_outlined),
              validator: (v) => (v == null || v.trim().length < 10) ? 'أدخل رقم جوال صحيح' : null,
            ),
            SizedBox(height: Responsive.spacing(context, 18)),
            _sectionLabel('كلمة المرور'),
            SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: inputDecoration(
                'كلمة المرور',
                '8 أحرف على الأقل',
                Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'كلمة المرور 8 أحرف على الأقل' : null,
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: inputDecoration(
                'تأكيد كلمة المرور',
                'أعد إدخال كلمة المرور',
                Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v != _passwordController.text) return 'كلمة المرور غير متطابقة';
                return null;
              },
            ),
            SizedBox(height: Responsive.spacing(context, 24)),
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
                        Icon(Icons.check_circle_outline_rounded, size: 22),
                        SizedBox(width: 10),
                        Text('إنشاء الحساب', style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 13),
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
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
          Text('لديك حساب بالفعل؟ ', style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: Responsive.fontSize(context, 14))),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: Text('تسجيل الدخول', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w700, fontSize: Responsive.fontSize(context, 15))),
          ),
        ],
      ),
    );
  }
}

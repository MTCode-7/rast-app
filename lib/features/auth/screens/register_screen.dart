import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/chat/screens/chat_screen.dart';

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

  bool _isStrongPassword(String value) {
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    return value.length >= 8 && hasUpper && hasLower && hasDigit;
  }

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
      final phone = _phoneController.text.trim();
      final data = await Api.auth.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: phone.isEmpty ? null : phone,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('SocketException')
                ? 'Check your internet connection'
                : e.toString(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
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
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'حساب جديد',
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
                      _header()
                          .animate()
                          .fadeIn(duration: 420.ms)
                          .slideY(begin: 0.1, end: 0),
                      SizedBox(height: Responsive.spacing(context, 20)),
                      _buildCard(context, isDark)
                          .animate()
                          .fadeIn(delay: 120.ms, duration: 420.ms)
                          .slideY(begin: 0.07, end: 0),
                      SizedBox(height: Responsive.spacing(context, 8)),
                      _bottomLink(),
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

  Widget _buildCard(BuildContext context, bool isDark) {
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
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: 'الاسم الكامل',
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            SizedBox(height: Responsive.spacing(context, 20)),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: 'البريد الإلكتروني',
                icon: Icons.email_outlined,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            SizedBox(height: Responsive.spacing(context, 20)),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: 'رقم الهاتف',
                icon: Icons.phone_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (v.trim().length < 9) return 'Invalid phone number';
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
                hint: 'كلمة المرور',
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
              validator: (v) => (v == null || !_isStrongPassword(v))
                  ? 'كلمة المرور يجب أن تحتوي على حرف كبير وصغير ورقم (8 أحرف على الأقل)'
                  : null,
            ),
            SizedBox(height: Responsive.spacing(context, 20)),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: 'تأكيد كلمة المرور',
                icon: Icons.lock_reset_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) => (v != _passwordController.text)
                  ? 'Passwords do not match'
                  : null,
            ),
            SizedBox(height: Responsive.spacing(context, 28)),
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
                      'إنشاء الحساب',
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

  Widget _header() {
    return Column(
      children: [
        Text(
          'إنشاء حساب جديد',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RastUi.blue,
            fontSize: Responsive.fontSize(context, 26),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 6)),
        Text(
          'أنشئ حسابك وابدأ بحجز التحاليل خلال ثواني',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RastUi.textPurple,
            fontSize: Responsive.fontSize(context, 14),
          ),
        ),
      ],
    );
  }

  Widget _bottomLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'لديك حساب بالفعل؟',
          style: TextStyle(color: Color(0xFFBDB9C3), fontSize: 12),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'تسجيل الدخول',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

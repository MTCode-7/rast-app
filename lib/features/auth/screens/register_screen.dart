import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/chat/screens/chat_screen.dart';

import '../../../app/main_shell.dart';
import '../../../core/constants/app_strings.dart';

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
      textDirection: settings.language == 'en'
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: RastUi.screenSurface(context),
        body: Stack(
          children: [
            Container(
              height: 240,
              decoration: const BoxDecoration(gradient: RastUi.headerGradient),
            ),
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
                          'registerTopTitle',
                          settings.language,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: 135,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.spacing(context, 16),
                  Responsive.spacing(context, 0),
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
                      _header()
                          .animate()
                          .fadeIn(duration: 420.ms)
                          .slideY(begin: 0.1, end: 0),

                      SizedBox(
                        height: Responsive.spacing(context, 24),
                      ),

                      _buildCard(context, isDark)
                          .animate()
                          .fadeIn(delay: 120.ms, duration: 420.ms)
                          .slideY(begin: 0.07, end: 0),

                      SizedBox(
                        height: Responsive.spacing(context, 14),
                      ),

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
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

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
                hint: AppStrings.t('fullName', lang),
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? AppStrings.t('nameRequired', lang)
                  : null,
            ),
            SizedBox(height: Responsive.spacing(context, 15)),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: AppStrings.t('email', lang),
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
            SizedBox(height: Responsive.spacing(context, 15)),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: AppStrings.t('phone', lang),
                icon: Icons.phone_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;

                if (v.trim().length < 9) {
                  return AppStrings.t('phoneInvalid', lang);
                }

                return null;
              },
            ),
            SizedBox(height: Responsive.spacing(context, 15)),
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
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
              (v == null || !_isStrongPassword(v))
                  ? AppStrings.t('strongPasswordError', lang)
                  : null,
            ),
            SizedBox(height: Responsive.spacing(context, 15)),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: _fieldDecoration(
                fill,
                primary: primary,
                label: '',
                hint: AppStrings.t('confirmPassword', lang),
                icon: Icons.lock_reset_rounded,
                suffix: IconButton(
                  icon:Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) =>
              v != _passwordController.text
                  ? AppStrings.t('passwordsDoNotMatch', lang)
                  : null,
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
                AppStrings.t('registerButton', lang),
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
        fontSize: Responsive.fontSize(context, 12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
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
    final settings = context.watch<AppSettingsProvider>();

    return Column(
      children: [
        Text(
          AppStrings.t(
            'registerTitle',
            settings.language,
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RastUi.blue,
            fontSize: Responsive.fontSize(context, 21),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          height: Responsive.spacing(context, 4),
        ),
        Text(
          AppStrings.t(
            'registerSubtitle',
            settings.language,
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RastUi.textPurple,
            fontSize: Responsive.fontSize(context, 12),
          ),
        ),
      ],
    );
  }

  Widget _bottomLink() {
    final settings = context.watch<AppSettingsProvider>();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.t(
                'alreadyHaveAccount',
                settings.language,
              ),
              style: const TextStyle(
                color: Color(0xFF535353),
                fontSize: 12,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppStrings.t(
                  'loginLink',
                  settings.language,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 2),

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
    );
  }
}

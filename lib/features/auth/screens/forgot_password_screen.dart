import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/chat/screens/chat_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _whatsappPhoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _formKey = GlobalKey<FormState>();
  final _whatsappFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _emailSent = false;
  bool _whatsappOtpSent = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  /// صيغ مقبولة للـ API: `05xxxxxxxx` أو `+9665xxxxxxxx` (انظر api.md)
  String _formatPhoneForAuthApi(String raw) {
    final s = raw.trim();
    if (s.startsWith('+966')) return s;
    final digits = s.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('966') && digits.length >= 12) {
      return '+$digits';
    }
    if (digits.startsWith('0')) return digits;
    if (digits.startsWith('5') && digits.length >= 9) return '0$digits';
    return digits.isNotEmpty ? digits : s;
  }

  /// يُحفظ لمطابقة طلب إعادة التعيين بـ OTP (نفس الصيغة المرسلة للخادم)
  String? _phoneSubmittedForOtp;

  bool _isStrongPassword(String value) {
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    return value.length >= 8 && hasUpper && hasLower && hasDigit;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _whatsappPhoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _sendEmailReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Api.auth.forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
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

  Future<void> _submitWhatsAppRequest() async {
    if (!_whatsappFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final phone = _formatPhoneForAuthApi(_whatsappPhoneController.text);
      _phoneSubmittedForOtp = phone;
      await Api.auth.forgotPasswordViaWhatsApp(phone);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _whatsappOtpSent = true;
      });
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
                ? 'تحقق من اتصال الإنترنت'
                : e.toString(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_emailSent) {
      return _buildEmailSuccessScreen();
    }
    if (_whatsappOtpSent) {
      return _buildOtpScreen();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: RastUi.screenSurface(context),
        body: Container(
          decoration: BoxDecoration(color: RastUi.screenSurface(context)),
          child: Stack(
            children: [
              Container(
                height: 132,
                decoration: const BoxDecoration(
                  gradient: RastUi.headerGradient,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: RastUi.cardSurface(context),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: const Text(
                        'استرجاع كلمة المرور',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      centerTitle: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 100),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: RastUi.softShadow,
                          border: Border.all(color: const Color(0xFFE8E6EE)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            gradient: RastUi.brandGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFFC8C8C8),
                          tabs: const [
                            Tab(
                              text: 'Email',
                              icon: Icon(Icons.email_outlined),
                            ),
                            Tab(
                              text: 'WhatsApp',
                              icon: Icon(Icons.chat_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildEmailTab(context, isDark),
                          _buildWhatsAppTab(isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSuccessScreen() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: RastUi.screenSurface(context),
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.spacing(context, 28),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGradientCheckMark(),
                      SizedBox(height: Responsive.spacing(context, 70)),
                      Text(
                        'تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني بنجاح',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RastUi.primaryText(context),
                          fontSize: Responsive.fontSize(context, 24),
                          fontWeight: FontWeight.w800,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _supportBubble(),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpScreen() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: RastUi.screenSurface(context),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.spacing(context, 30),
                  4,
                  Responsive.spacing(context, 30),
                  Responsive.spacing(context, 92),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        onPressed: () =>
                            setState(() => _whatsappOtpSent = false),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 70)),
                    Text(
                      'أدخل رمز التحقق',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 30),
                        fontWeight: FontWeight.w800,
                        color: RastUi.blue,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 18)),
                    Text(
                      'تم إرسال رمز مكون من 6 أرقام إلى رقمك عبر واتساب',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 17),
                        color: RastUi.secondaryText(context),
                        height: 1.7,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 54)),
                    Row(
                      textDirection: TextDirection.ltr,
                      children: List.generate(_otpControllers.length, (index) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _otpBox(index),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: Responsive.spacing(context, 30)),
                    _passwordField(
                      controller: _newPasswordController,
                      label: 'كلمة المرور الجديدة',
                      obscure: _obscureNewPassword,
                      onToggle: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 14)),
                    _passwordField(
                      controller: _confirmPasswordController,
                      label: 'تأكيد كلمة المرور',
                      obscure: _obscureConfirmPassword,
                      onToggle: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 28)),
                    Text(
                      'سنعيد إرسال الرمز خلال 59 ثانية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 15),
                        color: RastUi.secondaryText(context),
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 28)),
                    _gradientActionButton(
                      label: 'تأكيد الرمز',
                      onPressed: _isLoading ? null : _confirmOtp,
                    ),
                    SizedBox(height: Responsive.spacing(context, 24)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text.rich(
                        TextSpan(
                          text: 'هل تذكرت كلمة المرور؟ ',
                          style: TextStyle(
                            color: RastUi.secondaryText(context),
                            fontSize: Responsive.fontSize(context, 16),
                          ),
                          children: [
                            TextSpan(
                              text: 'سجل الدخول',
                              style: TextStyle(
                                color: RastUi.blue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _supportBubble(),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return TextField(
      controller: _otpControllers[index],
      focusNode: _otpFocusNodes[index],
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      maxLength: 1,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        color: RastUi.primaryText(context),
        fontSize: Responsive.fontSize(context, 34),
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: RastUi.subtleFill(context),
        contentPadding: EdgeInsets.symmetric(
          vertical: Responsive.spacing(context, 16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: RastUi.softBorder(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RastUi.blue, width: 1.4),
        ),
      ),
      onChanged: (value) {
        if (value.isNotEmpty && index < _otpFocusNodes.length - 1) {
          _otpFocusNodes[index + 1].requestFocus();
        }
        if (value.isEmpty && index > 0) {
          _otpFocusNodes[index - 1].requestFocus();
        }
      },
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: RastUi.subtleFill(context),
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: RastUi.softBorder(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RastUi.blue, width: 1.4),
        ),
      ),
    );
  }

  Future<void> _confirmOtp() async {
    final code = _otpControllers.map((controller) => controller.text).join();
    final password = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;
    if (code.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل رمز التحقق كاملاً')));
      return;
    }
    if (!_isStrongPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'كلمة المرور يجب أن تحتوي حرف كبير وحرف صغير ورقم (8 أحرف على الأقل)',
          ),
        ),
      );
      return;
    }
    if (password != confirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور وتأكيدها غير متطابقين')),
      );
      return;
    }
    final phone = _phoneSubmittedForOtp;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أعد طلب الرمز من شاشة واتساب')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Api.auth.resetPasswordOtp(
        phone: phone,
        otp: code,
        password: password,
        passwordConfirmation: confirmation,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
      );
      Navigator.pop(context);
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
        SnackBar(content: Text(e.toString().split('\n').first)),
      );
    }
  }

  Widget _buildGradientCheckMark() {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            RastUi.blue.withValues(alpha: 0.32),
            RastUi.purple.withValues(alpha: 0.34),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RastUi.headerGradient,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 58),
        ),
      ),
    );
  }

  Widget _gradientActionButton({
    required String label,
    VoidCallback? onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RastUi.brandGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: RastUi.purple.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            vertical: Responsive.spacing(context, 18),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: Responsive.fontSize(context, 18),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _supportBubble() {
    return RastSupportBubble(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      ),
    );
  }

  Widget _buildEmailTab(BuildContext context, bool isDark) {
    if (_emailSent) {
      return Center(
        child: _surfaceCard(
          isDark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mark_email_read_rounded,
                size: 56,
                color: Colors.green.shade700,
              ),
              SizedBox(height: Responsive.spacing(context, 12)),
              const Text(
                'Email Sent Successfully',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: Responsive.spacing(context, 8)),
              const Text(
                'Check your inbox and follow the reset link.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      child: _surfaceCard(
        isDark,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_reset_rounded,
                size: 54,
                color: context.watch<AppSettingsProvider>().primaryColor,
              ),
              SizedBox(height: Responsive.spacing(context, 12)),
              const Text(
                'Enter your email to receive a reset link',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.spacing(context, 18)),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@email.com',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: context
                        .watch<AppSettingsProvider>()
                        .primaryColor
                        .withValues(alpha: 0.85),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              SizedBox(height: Responsive.spacing(context, 18)),
              FilledButton(
                onPressed: _isLoading ? null : _sendEmailReset,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      child: _surfaceCard(
        isDark,
        child: Form(
          key: _whatsappFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.chat_rounded, size: 54, color: RastUi.purple),
              SizedBox(height: Responsive.spacing(context, 12)),
              const Text(
                'Enter your registered phone number',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.spacing(context, 18)),
              TextFormField(
                controller: _whatsappPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '05xxxxxxxx',
                  prefixIcon: Icon(
                    Icons.phone_android_outlined,
                    color: context
                        .watch<AppSettingsProvider>()
                        .primaryColor
                        .withValues(alpha: 0.85),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone is required';
                  final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length < 9) return 'Invalid phone number';
                  return null;
                },
              ),
              SizedBox(height: Responsive.spacing(context, 18)),
              FilledButton.icon(
                onPressed: _isLoading ? null : _submitWhatsAppRequest,
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Send via WhatsApp'),
                style: FilledButton.styleFrom(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surfaceCard(bool isDark, {required Widget child}) {
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      decoration: BoxDecoration(
        gradient: RastUi.headerGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

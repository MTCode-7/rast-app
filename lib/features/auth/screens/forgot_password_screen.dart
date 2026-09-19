import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/chat/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../profile/screens/profile_screen.dart';

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

  Future<void> _launchSupportCall() async {
    final lang = context.read<AppSettingsProvider>().language;

    final uri = Uri.parse(
      'tel:${ProfileScreen.supportPhoneDisplay}',
    );

    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.t(
              'cannotOpenCall',
              lang,
            ),
          ),
        ),
      );

      return;
    }

    await launchUrl(uri);
  }

  Future<void> _launchSupportWhatsApp() async {
    final lang = context.read<AppSettingsProvider>().language;

    final uri = Uri.parse(
      'https://wa.me/${ProfileScreen.supportPhoneWhatsApp}',
    );

    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.t(
              'cannotOpenWhatsapp',
              lang,
            ),
          ),
        ),
      );

      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
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
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textDirection =
    lang == 'en' ? TextDirection.ltr : TextDirection.rtl;

    if (_emailSent) {
      return _buildEmailSuccessScreen();
    }

    if (_whatsappOtpSent) {
      return _buildOtpScreen();
    }

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: RastUi.screenSurface(context),
        body: Stack(
          children: [
            SingleChildScrollView(

              padding: EdgeInsets.only(
                bottom: Responsive.spacing(context, 15),
              ),
              child: Column(
                children: [
                  // White top header
                  SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            AppStrings.t(
                              'forgotPasswordTitle',
                              lang,
                            ),
                            style: TextStyle(
                              color: RastUi.primaryText(context),
                              fontSize: Responsive.fontSize(context, 16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: RastUi.primaryText(context),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Purple hero
                  Container(
                    height: 255,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: RastUi.headerGradient,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: Responsive.spacing(context, 28),
                        ),

                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: Responsive.spacing(context, 10),
                        ),

                        Text(
                          AppStrings.t(
                            'forgotPasswordHeading',
                            lang,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Responsive.fontSize(context, 20),
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        SizedBox(
                          height: Responsive.spacing(context, 6),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                          ),
                          child: Text(
                            AppStrings.t(
                              'forgotPasswordSubtitle',
                              lang,
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: Responsive.fontSize(context, 11),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating tabs
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: RastUi.screenSurface(context)
                              .withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: RastUi.cardSurface(context),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          labelColor: settings.primaryColor,
                          unselectedLabelColor:
                          const Color(0xFF535353),
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.email_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    AppStrings.t(
                                      'email',
                                      lang,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    AppStrings.t(
                                      'whatsapp',
                                      lang,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Transform.translate(
                    offset: const Offset(0, -12),
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        return _tabController.index == 0
                            ? _buildEmailTab(
                          context,
                          isDark,
                        )
                            : _buildWhatsAppTab(
                          isDark,
                        );
                      },
                    ),
                  ),

                  SizedBox(
                    height: Responsive.spacing(context, 10),
                  ),

                  _buildHelpSection(
                    lang,
                    settings,
                  ),
                  SizedBox(
                    height: Responsive.spacing(context, 28),
                  ),

                  _buildFooter(lang),
                ],
              ),
            ),

            _supportBubble(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(String lang) {
    final settings = context.read<AppSettingsProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        9,
        16,
        8,
      ),
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        border: Border(
          top: BorderSide(
            color: RastUi.softBorder(context),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Contact us
            GestureDetector(
              onTap: _showHelpCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.t(
                      'contactWithUs',
                      lang,
                    ),
                    style: TextStyle(
                      color: const Color(0xFF535353),
                      fontSize: Responsive.fontSize(context, 11),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(width: 6),

                  Icon(
                    Icons.mail_outline_rounded,
                    size: 16,
                    color: const Color(0xFF535353),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 7),

            // Security + copyright
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 12,
                  color: settings.primaryColor,
                ),

                const SizedBox(width: 5),

                Text(
                  AppStrings.t(
                    'securePass',
                    lang,
                  ),
                  style: TextStyle(
                    color: Color(0xFF535353),
                    fontSize: Responsive.fontSize(context, 11),
                    fontWeight: FontWeight.w700,
                  ),
                ),

                 Container(height: 10,width: 1, color: Color(0xFF535353),
                 margin: EdgeInsets.symmetric(horizontal: 10),
                 ),

                Text(
                  AppStrings.t(
                    'allRightsReserved',
                    lang,
                  ),
                  style: TextStyle(
                    color: Color(0xFF535353),
                    fontSize: Responsive.fontSize(context, 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildHelpSection(
      String lang,
      AppSettingsProvider settings,
      ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: lang == 'ar'
                ? [
              GestureDetector(
                onTap: _showHelpCenter,
                child: Icon(
                  Icons.help_outline_rounded,
                  color: settings.primaryColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppStrings.t('needHelp', lang),
                style: TextStyle(
                  color: settings.primaryColor,
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]
                : [
              Text(
                AppStrings.t('needHelp', lang),
                style: TextStyle(
                  color: settings.primaryColor,
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showHelpCenter,
                child: Icon(
                  Icons.help_outline_rounded,
                  color: settings.primaryColor,
                  size: 19,
                ),
              ),
            ],
          ),

          SizedBox(
            height: Responsive.spacing(context, 16),
          ),

          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, 18),
              vertical: Responsive.spacing(context, 18),
            ),
            decoration: BoxDecoration(
              color: RastUi.subtleFill(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: settings.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      AppStrings.t('needHelpTitle', lang),
                      style: TextStyle(
                        color: settings.primaryColor,
                        fontSize: Responsive.fontSize(context, 12),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height: Responsive.spacing(context, 10),
                ),

                Text(
                  AppStrings.t('needHelpMessage', lang),
                  textAlign: TextAlign.start,
                  softWrap: true,
                  style: TextStyle(
                    color: RastUi.secondaryText(context),
                    fontSize: Responsive.fontSize(context, 11),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: Responsive.spacing(context, 12),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppStrings.t('rememberPassword', lang),
                style: TextStyle(
                  color:Color(0xFF535353),
                  fontSize: Responsive.fontSize(context, 11),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.t('loginLink', lang),
                  style: TextStyle(
                    color: settings.primaryColor,
                    fontSize: Responsive.fontSize(context, 11),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHelpCenter() {
    final lang = context.read<AppSettingsProvider>().language;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection:
        lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            AppStrings.t('helpCenter', lang),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.t(
                    'helpCenterMessage',
                    lang,
                  ),
                  style: TextStyle(
                    color: RastUi.secondaryText(ctx),
                  ),
                ),

                const SizedBox(height: 16),

                Directionality(
                  textDirection:
                  lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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

                      const SizedBox(width: 8),

                      IconButton(
                        tooltip: AppStrings.t('copy', lang),
                        onPressed: () async {
                          await Clipboard.setData(
                            const ClipboardData(
                              text: ProfileScreen.supportPhoneDisplay,
                            ),
                          );

                          if (!ctx.mounted) return;

                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppStrings.t('copied', lang),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 20,
                          color: RastUi.purple,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _launchSupportWhatsApp();
                  },
                  icon: const Icon(
                    Icons.chat_rounded,
                  ),
                  label: Text(
                    AppStrings.t(
                      'whatsapp',
                      lang,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _launchSupportCall();
                  },
                  icon: const Icon(
                    Icons.phone_rounded,
                  ),
                  label: Text(
                    AppStrings.t(
                      'call',
                      lang,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppStrings.t(
                  'close',
                  lang,
                ),
              ),
            ),
          ],
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
            vertical: Responsive.spacing(context, 10),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 15),

            const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
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
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 24),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          Responsive.spacing(context, 24),
        ),
        decoration: BoxDecoration(
          color: RastUi.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: RastUi.softBorder(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.10,
              ),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.t(
                  'forgotEmailInstruction',
                  lang,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RastUi.primaryText(context),
                  fontSize:
                  Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),

              SizedBox(
                height:
                Responsive.spacing(context, 28),
              ),

              TextFormField(
                controller: _emailController,
                keyboardType:
                TextInputType.emailAddress,
                decoration: _forgotFieldDecoration(
                  hint: AppStrings.t(
                    'emailHint',
                    lang,
                  ),
                  icon: Icons.email_outlined,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return AppStrings.t(
                      'emailRequired',
                      lang,
                    );
                  }

                  if (!v.contains('@')) {
                    return AppStrings.t(
                      'emailInvalid',
                      lang,
                    );
                  }

                  return null;
                },
              ),

              SizedBox(
                height:
                Responsive.spacing(context, 20),
              ),

              _gradientActionButton(
                label: AppStrings.t(
                  'sendResetLink',
                  lang,
                ),
                onPressed:
                _isLoading ? null : _sendEmailReset,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppTab(bool isDark) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 24),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          Responsive.spacing(context, 24),
        ),
        decoration: BoxDecoration(
          color: RastUi.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: RastUi.softBorder(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.10,
              ),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Form(
          key: _whatsappFormKey,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.t(
                  'registeredPhone',
                  lang,
                ),
                style: TextStyle(
                  color: RastUi.primaryText(context),
                  fontSize:
                  Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(
                height:
                Responsive.spacing(context, 20),
              ),

              TextFormField(
                controller:
                _whatsappPhoneController,
                keyboardType: TextInputType.phone,
                decoration: _forgotFieldDecoration(
                  hint: '+966 5X XXX XXXX',
                  icon:
                  Icons.phone_android_outlined,
                ),
                validator: (v) {
                  if (v == null ||
                      v.trim().isEmpty) {
                    return AppStrings.t(
                      'phoneRequired',
                      lang,
                    );
                  }

                  final digits = v.replaceAll(
                    RegExp(r'[^\d]'),
                    '',
                  );

                  if (digits.length < 9) {
                    return AppStrings.t(
                      'phoneInvalid',
                      lang,
                    );
                  }

                  return null;
                },
              ),

              SizedBox(
                height:
                Responsive.spacing(context, 10),
              ),

              Text(
                AppStrings.t(
                  'whatsappCodeHint',
                  lang,
                ),
                style: TextStyle(
                  color:
                  Color(0xFF535353),
                  fontSize:
                  Responsive.fontSize(context, 11),
                ),
              ),

              SizedBox(
                height:
                Responsive.spacing(context, 22),
              ),

              _gradientActionButton(
                label: AppStrings.t(
                  'sendViaWhatsapp',
                  lang,
                ),
                onPressed: _isLoading
                    ? null
                    : _submitWhatsAppRequest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _forgotFieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    final primary =
        context.watch<AppSettingsProvider>().primaryColor;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: RastUi.secondaryText(context),
        fontSize: Responsive.fontSize(
          context,
          13,
        ),
      ),
      prefixIcon: Icon(
        icon,
        color: RastUi.secondaryText(context),
        size: 20,
      ),
      filled: true,
      fillColor: RastUi.screenSurface(context),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(
          color: RastUi.softBorder(context),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(
          color: RastUi.softBorder(context),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(
          color: primary,
          width: 1.5,
        ),
      ),
    );
  }

}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _whatsappFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _emailSent = false;

  static const String _defaultWhatsAppNumber = '966501234567';

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

  Future<void> _openWhatsApp() async {
    if (!_whatsappFormKey.currentState!.validate()) return;
    final phone = _whatsappPhoneController.text.trim().replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    final userPhone = phone.startsWith('0')
        ? '966${phone.substring(1)}'
        : (phone.startsWith('966') ? phone : '966$phone');

    final message =
        'Hello, I need a password reset for my Rast account. My phone: $userPhone';

    final uri = Uri.parse(
      'https://wa.me/$_defaultWhatsAppNumber?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open WhatsApp')));
    }
  }

  Future<void> _submitWhatsAppRequest() async {
    if (!_whatsappFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _openWhatsApp();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent. We will contact you shortly.'),
        ),
      );
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: settings.primaryGradient),
          child: Stack(
            children: [
              Positioned(top: -60, right: -60, child: _deco(160)),
              Positioned(bottom: 110, left: -60, child: _deco(140)),
              SafeArea(
                child: Column(
                  children: [
                    AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: const Text(
                        'Reset Password',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      centerTitle: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
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
                    color: context.watch<AppSettingsProvider>().primaryColor.withValues(alpha: 0.85),
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
              const Icon(
                Icons.chat_rounded,
                size: 54,
                color: Color(0xFF25D366),
              ),
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
                  hintText: '05xxxxxxxx or 9665xxxxxxxx',
                  prefixIcon: Icon(
                    Icons.phone_android_outlined,
                    color: context.watch<AppSettingsProvider>().primaryColor.withValues(alpha: 0.85),
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
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                ),
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
        color: isDark ? const Color(0xFF162033) : Colors.white,
        borderRadius: BorderRadius.circular(24),
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

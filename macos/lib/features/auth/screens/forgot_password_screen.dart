import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
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

  Future<void> _openWhatsApp() async {
    if (!_whatsappFormKey.currentState!.validate()) return;
    final phone = _whatsappPhoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    final userPhone = phone.startsWith('0') ? '966${phone.substring(1)}' : (phone.startsWith('966') ? phone : '966$phone');
    final message = 'السلام عليكم، أود استعادة كلمة المرور لحسابي في تطبيق راست. رقمي: $userPhone';
    final uri = Uri.parse('https://wa.me/$_defaultWhatsAppNumber?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
      }
    }
  }

  Future<void> _submitWhatsAppRequest() async {
    if (!_whatsappFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _openWhatsApp();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('سنرسل لك رابط التأكيد أو رمز OTP عبر واتساب قريباً')),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Stack(
            children: [
              Positioned(top: -60, right: -60, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
              Positioned(bottom: 150, left: -50, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)))),
              SafeArea(
                child: Column(
                  children: [
                    AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    'استعادة كلمة المرور',
                    style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.w600),
                  ),
                  centerTitle: true,
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: AppTheme.accent,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(icon: Icon(Icons.email_outlined), text: 'بالبريد الإلكتروني'),
                    Tab(icon: Icon(Icons.chat_outlined), text: 'بواتساب'),
                  ],
                ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildEmailTab(),
                          _buildWhatsAppTab(),
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

  Widget _buildEmailTab() {
    if (_emailSent) {
      return Padding(
        padding: EdgeInsets.all(Responsive.spacing(context, 24)),
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 28)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mark_email_read_rounded, size: 56, color: Colors.green.shade700),
              ),
              SizedBox(height: Responsive.spacing(context, 20)),
              Text(
                'تم الإرسال بنجاح!',
                style: TextStyle(fontSize: Responsive.fontSize(context, 20), fontWeight: FontWeight.bold),
              ),
              SizedBox(height: Responsive.spacing(context, 8)),
              Text(
                'تحقق من بريدك الإلكتروني واتبع الرابط لإعادة تعيين كلمة المرور.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.spacing(context, 24)),
      child: Container(
        padding: EdgeInsets.all(Responsive.spacing(context, 24)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 12)),
            BoxShadow(color: AppTheme.primary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_reset_rounded, size: 56, color: AppTheme.primary.withValues(alpha: 0.8)),
              SizedBox(height: Responsive.spacing(context, 16)),
              Text(
                'أدخل بريدك الإلكتروني وسنرسل لك رابط استعادة كلمة المرور',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: AppTheme.onSurfaceVariant),
              ),
              SizedBox(height: Responsive.spacing(context, 24)),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'أدخل البريد الإلكتروني';
                  if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                  return null;
                },
              ),
              SizedBox(height: Responsive.spacing(context, 24)),
              FilledButton(
                onPressed: _isLoading ? null : _sendEmailReset,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('إرسال الرابط', style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.spacing(context, 24)),
      child: Container(
        padding: EdgeInsets.all(Responsive.spacing(context, 24)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFF25D366).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Form(
          key: _whatsappFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat_rounded, size: 56, color: const Color(0xFF25D366)),
              ),
              SizedBox(height: Responsive.spacing(context, 20)),
              Text(
                'استعادة كلمة المرور عبر واتساب',
                style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.spacing(context, 10)),
              Text(
                'أدخل رقم جوالك المسجل. سنرسل لك رابط التأكيد أو رمز OTP عبر واتساب',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: AppTheme.onSurfaceVariant),
              ),
              SizedBox(height: Responsive.spacing(context, 24)),
              TextFormField(
                controller: _whatsappPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال',
                  hintText: '05xxxxxxxx أو 9665xxxxxxxx',
                  prefixIcon: Icon(Icons.phone_android_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'أدخل رقم الجوال';
                  final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length < 9) return 'رقم غير صحيح';
                  return null;
                },
              ),
              SizedBox(height: Responsive.spacing(context, 24)),
              FilledButton.icon(
                onPressed: _isLoading ? null : _submitWhatsAppRequest,
                icon: Icon(Icons.chat_rounded, color: Colors.white, size: 22),
                label: Text(
                  'إرسال وفتح واتساب',
                  style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

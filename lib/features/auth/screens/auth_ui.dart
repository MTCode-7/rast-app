import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// هيكل شاشات الدخول/التسجيل/الاستعادة: رأس بتدرج الهوية وشعار متحرك،
/// وورقة بيضاء مستديرة تحمل النموذج. يحترم الاتجاه والوضع الداكن.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBack = true,
    this.onBack,
    this.floating,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isRtl = settings.isArabic;
    final top = MediaQuery.paddingOf(context).top;
    final canPop = showBack && (onBack != null || Navigator.of(context).canPop());

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        body: Stack(
          children: [
            // الرأس: تدرج + دوائر زخرفية خفيفة
            Container(
              height: 300 + top,
              decoration: const BoxDecoration(gradient: RastTokens.heroGradient),
              child: Stack(
                children: [
                  PositionedDirectional(
                    top: -60,
                    end: -50,
                    child: _blob(190, 0.10),
                  ),
                  PositionedDirectional(
                    top: 120 + top,
                    start: -70,
                    child: _blob(160, 0.07),
                  ),
                ],
              ),
            ),
            SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        if (canPop)
                          Pressable(
                            onTap: onBack ?? () => Navigator.of(context).maybePop(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                              ),
                              child: Icon(
                                isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                                textDirection: TextDirection.ltr,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Center(child: RastLogo(size: 118, light: true))
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack, duration: 600.ms),
                  const SizedBox(height: 26),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: BoxDecoration(
                      color: RastTokens.card(context),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2A1A4A).withValues(alpha: 0.14),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: RastTokens.ink(context)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, height: 1.6, color: RastTokens.muted(context)),
                        ),
                        const SizedBox(height: 22),
                        child,
                      ],
                    ),
                  ).animate().fadeIn(delay: 120.ms, duration: 450.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                  if (footer != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: footer!,
                    ).animate().fadeIn(delay: 260.ms),
                  SizedBox(height: 110 + MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
            ?floating,
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

/// تنسيق موحّد لحقول النماذج: تعبئة ناعمة، زوايا 16، أيقونة بلون الهوية، حد واضح عند التركيز والخطأ.
InputDecoration authInputDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  Widget? suffix,
  String? label,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13.5, color: RastTokens.muted(context)),
    prefixIcon: Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      child: Icon(icon, color: RastTokens.brand, size: 21),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    suffixIcon: suffix,
    filled: true,
    fillColor: RastTokens.fill(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: border(Colors.transparent),
    enabledBorder: border(Colors.transparent),
    focusedBorder: border(RastTokens.brand, 1.6),
    errorBorder: border(RastTokens.danger.withValues(alpha: 0.7)),
    focusedErrorBorder: border(RastTokens.danger, 1.6),
    errorStyle: const TextStyle(fontSize: 12, height: 1.3),
  );
}

/// سطر رابط أسفل النموذج: «ليس لديك حساب؟ أنشئ حساباً».
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({super.key, required this.text, required this.action, required this.onTap});

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: TextStyle(color: RastTokens.muted(context), fontSize: 13.5)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
          child: Text(
            action,
            style: const TextStyle(color: RastTokens.brand, fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// زر ممتلئ بتدرج لوني من لوني الإعدادات (primary → secondary) ليتوافق مع خلفيات التسجيل والدخول
class GradientFilledButton extends StatelessWidget {
  const GradientFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final gradient = settings.primaryGradient;
    // ضغطة محسوسة: الزر يصغر قليلاً ويرتد مع اهتزاز خفيف
    return Pressable(
      scale: onPressed == null ? 1 : 0.97,
      haptic: false,
      child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: settings.primaryColor.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: _withHaptic(onPressed),
        style: (style ?? const ButtonStyle()).copyWith(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        ),
        child: child,
      ),
      ),
    );
  }
}

VoidCallback? _withHaptic(VoidCallback? onPressed) => onPressed == null
    ? null
    : () {
        HapticFeedback.selectionClick();
        onPressed();
      };

/// زر ممتلئ بتدرج مع أيقونة ونص — يستخدم لوني الإعدادات مع التدرج
class GradientFilledButtonIcon extends StatelessWidget {
  const GradientFilledButtonIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final gradient = settings.primaryGradient;
    return Pressable(
      scale: onPressed == null ? 1 : 0.97,
      haptic: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: RastUi.purple.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: _withHaptic(onPressed),
          icon: icon,
          label: label,
          style: (style ?? const ButtonStyle()).copyWith(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
            surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
      ),
    );
  }
}

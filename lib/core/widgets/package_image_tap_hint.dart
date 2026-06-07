import 'package:flutter/material.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
import 'package:rast/core/services/onboarding_service.dart';
import 'package:rast/core/theme/app_theme.dart';

/// تنويه لمرة واحدة: صور الباقة قابلة للنقر للتكبير.
class PackageImageTapHintBanner extends StatelessWidget {
  const PackageImageTapHintBanner({
    super.key,
    required this.message,
    required this.onDismiss,
    this.compact = false,
  });

  final String message;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.touch_app_rounded,
              color: Colors.white,
              size: compact ? 20 : 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'إغلاق',
            ),
          ],
        ),
      ),
    );
  }
}

/// يتحقق ويُظهر التنويه عند أول فتح لباقة بها صور.
mixin PackageImageTapHintMixin<T extends StatefulWidget> on State<T> {
  bool _showPackageImageTapHint = false;

  bool get showPackageImageTapHint => _showPackageImageTapHint;

  Future<void> preparePackageImageTapHint({required bool hasImages}) async {
    if (!hasImages) return;
    final show = await OnboardingService.shouldShow(
      OnboardingTourIds.packageImageTapHint,
    );
    if (mounted && show) {
      setState(() => _showPackageImageTapHint = true);
    }
  }

  void dismissPackageImageTapHint() {
    if (!_showPackageImageTapHint) return;
    OnboardingService.markSeen(OnboardingTourIds.packageImageTapHint);
    if (mounted) setState(() => _showPackageImageTapHint = false);
  }

  Widget? buildPackageImageTapHintOverlay({
    required String message,
    bool compact = false,
    double bottom = 88,
  }) {
    if (!_showPackageImageTapHint) return null;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: PackageImageTapHintBanner(
        message: message,
        compact: compact,
        onDismiss: dismissPackageImageTapHint,
      ),
    );
  }
}

/// شارة دائمة على صورة الغلاف: الصورة قابلة للنقر.
class PackageHeroTapChip extends StatelessWidget {
  const PackageHeroTapChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة صغيرة دائمة (اختياري) بجانب عنوان قسم الصور.
class PackageImageTapBadge extends StatelessWidget {
  const PackageImageTapBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.zoom_in_rounded, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

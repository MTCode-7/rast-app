import 'package:flutter/material.dart';
import 'package:rast/core/onboarding/onboarding_coach.dart';
import 'package:rast/core/onboarding/onboarding_guide_sheet.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// زر مساعدة صغير (؟) — جولة الشاشة أو دليل الحجز الكامل.
class RastHelpButton extends StatelessWidget {
  const RastHelpButton({
    super.key,
    this.tourId,
    this.tourSteps,
    this.showBookingGuide = true,
    this.size = 36,
  });

  final String? tourId;
  final List<OnboardingStep>? tourSteps;
  final bool showBookingGuide;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _onTap(context),
        child: SizedBox(
          width: size,
          height: size,
          child: const Icon(
            Icons.help_outline_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: RastUi.cardSurface(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tourId != null && tourSteps != null && tourSteps!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline_rounded,
                        color: RastUi.purple),
                    title: const Text('جولة سريعة لهذه الشاشة'),
                    subtitle: const Text('إرشادات تفاعلية على الأزرار'),
                    onTap: () {
                      Navigator.pop(ctx);
                      OnboardingCoach.show(
                        context,
                        tourId: tourId!,
                        steps: tourSteps!,
                        force: true,
                      );
                    },
                  ),
                if (showBookingGuide)
                  ListTile(
                    leading: const Icon(Icons.menu_book_rounded,
                        color: RastUi.purple),
                    title: const Text('كيف أحجز؟ (دليل كامل)'),
                    subtitle: const Text('خطوات الحجز من البداية للنهاية'),
                    onTap: () {
                      Navigator.pop(ctx);
                      OnboardingGuideSheet.show(context);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

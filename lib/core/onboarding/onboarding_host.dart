import 'package:flutter/material.dart';
import 'package:rast/core/onboarding/onboarding_coach.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
/// يعرض جولة تلقائية عند أول زيارة للشاشة.
mixin OnboardingTourHost<T extends StatefulWidget> on State<T> {
  String? get onboardingTourId;
  List<OnboardingStep> buildOnboardingSteps();

  void scheduleOnboardingTour({Duration delay = const Duration(milliseconds: 600)}) {
  final id = onboardingTourId;
    if (id == null) return;
    // جولة تلقائية واحدة فقط (الترحيب عند أول فتح). جولات الشاشات الأخرى كانت تقاطع المستخدم
    // في كل صفحة وتؤخر الحجز، فصارت تُعرض عند طلبها من زر المساعدة (?) فقط.
    if (id != OnboardingTourIds.appMain) return;
    Future<void>.delayed(delay, () async {
      if (!mounted) return;
      final steps = buildOnboardingSteps();
      if (steps.isEmpty) return;
      await OnboardingCoach.show(context, tourId: id, steps: steps);
    });
  }

  void replayOnboardingTour() {
    final id = onboardingTourId;
    if (id == null) return;
    OnboardingCoach.show(
      context,
      tourId: id,
      steps: buildOnboardingSteps(),
      force: true,
    );
  }
}

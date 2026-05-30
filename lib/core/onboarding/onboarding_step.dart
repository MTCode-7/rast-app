import 'package:flutter/material.dart';

enum OnboardingTooltipAlign {
  auto,
  above,
  below,
}

class OnboardingStep {
  const OnboardingStep({
    this.targetKey,
    required this.title,
    required this.body,
    this.align = OnboardingTooltipAlign.auto,
  });

  /// عنصر يُسلّط عليه الضوء. إن كان null تُعرض البطاقة في منتصف الشاشة.
  final GlobalKey? targetKey;
  final String title;
  final String body;
  final OnboardingTooltipAlign align;
}

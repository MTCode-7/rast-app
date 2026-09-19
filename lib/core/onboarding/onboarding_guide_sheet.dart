import 'package:flutter/material.dart';
import 'package:rast/core/onboarding/onboarding_catalog.dart';
import 'package:rast/core/services/onboarding_service.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// دليل نصي كامل: كيفية الحجز في التطبيق.
class OnboardingGuideSheet {
  OnboardingGuideSheet._();

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          decoration: BoxDecoration(
            color: RastUi.cardSurface(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.spacing(ctx, 20),
                  Responsive.spacing(ctx, 16),
                  Responsive.spacing(ctx, 12),
                  Responsive.spacing(ctx, 8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: RastUi.brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'كيف أحجز تحليلاً؟',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(ctx, 20),
                          fontWeight: FontWeight.w800,
                          color: RastUi.primaryText(ctx),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.spacing(ctx, 20),
                    0,
                    Responsive.spacing(ctx, 20),
                    Responsive.spacing(ctx, 20) +
                        MediaQuery.paddingOf(ctx).bottom,
                  ),
                  itemCount: OnboardingCatalog.bookingGuideSections.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: Responsive.spacing(ctx, 14)),
                  itemBuilder: (context, i) {
                    final s = OnboardingCatalog.bookingGuideSections[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RastUi.softBorder(ctx)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['title']!,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(ctx, 15),
                              fontWeight: FontWeight.w800,
                              color: RastUi.purple,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s['body']!,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(ctx, 14),
                              height: 1.5,
                              color: RastUi.secondaryText(ctx),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.spacing(ctx, 20),
                  0,
                  Responsive.spacing(ctx, 20),
                  Responsive.spacing(ctx, 16) + MediaQuery.paddingOf(ctx).bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      OnboardingService.markBookingGuideSeen();
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: RastUi.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('فهمت، شكراً'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

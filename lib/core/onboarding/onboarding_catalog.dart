import 'package:flutter/material.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
/// نصوص وخطوات الجولات التعليمية.
class OnboardingCatalog {
  OnboardingCatalog._();

  static List<OnboardingStep> appMainTour({
    GlobalKey? navHomeKey,
    GlobalKey? navBookingsKey,
    GlobalKey? navLabsKey,
    GlobalKey? chatFabKey,
  }) =>
      [
        const OnboardingStep(
          title: 'مرحباً في راست لابس',
          body:
              'من هنا تتصفّح التحاليل والمختبرات وتحجز موعدك بسهولة. نبدأ جولة سريعة على أهم الأزرار.',
        ),
        OnboardingStep(
          targetKey: navHomeKey,
          title: 'الرئيسية',
          body: 'البحث عن تحاليل، الباقات، والمختبرات المميزة.',
          align: OnboardingTooltipAlign.above,
        ),
        OnboardingStep(
          targetKey: navLabsKey,
          title: 'المختبرات',
          body: 'قائمة كل المختبرات مع فلترة حسب المنطقة والقرب منك.',
          align: OnboardingTooltipAlign.above,
        ),
        OnboardingStep(
          targetKey: navBookingsKey,
          title: 'حجوزاتي',
          body: 'متابعة حجوزاتك السابقة والقادمة وحالة الدفع.',
          align: OnboardingTooltipAlign.above,
        ),
        OnboardingStep(
          targetKey: chatFabKey,
          title: 'المساعد',
          body: 'اسأل عن التحاليل أو المختبرات عبر المساعد الذكي.',
          align: OnboardingTooltipAlign.above,
        ),
      ];

  static List<OnboardingStep> homeTour({
    required GlobalKey searchKey,
    required GlobalKey categoriesKey,
    required GlobalKey labsSectionKey,
  }) =>
      [
        OnboardingStep(
          targetKey: searchKey,
          title: 'ابحث عن تحليل',
          body: 'اكتب اسم التحليل ثم اضغط بحث للانتقال مباشرة لنتائج التحاليل.',
          align: OnboardingTooltipAlign.below,
        ),
        OnboardingStep(
          targetKey: categoriesKey,
          title: 'التصنيفات',
          body: 'اختر نوع التحاليل (دم، هرمونات، …) لعرض ما يناسبك.',
          align: OnboardingTooltipAlign.below,
        ),
        OnboardingStep(
          targetKey: labsSectionKey,
          title: 'مختبرات قريبة',
          body: 'اضغط على أي مختبر لرؤية تحاليله والحجز، أو «عرض الكل» لقائمة المختبرات.',
          align: OnboardingTooltipAlign.above,
        ),
      ];

  static List<OnboardingStep> labsTour({
    required GlobalKey searchKey,
    required GlobalKey filterKey,
    required GlobalKey sortKey,
  }) =>
      [
        OnboardingStep(
          targetKey: searchKey,
          title: 'بحث عن مختبر',
          body: 'ابحث بالاسم أو المدينة الظاهرة تحت المختبر.',
          align: OnboardingTooltipAlign.below,
        ),
        OnboardingStep(
          targetKey: filterKey,
          title: 'فلترة المنطقة',
          body: 'اختر منطقتك لعرض المختبرات ضمن نطاقك الجغرافي.',
          align: OnboardingTooltipAlign.below,
        ),
        OnboardingStep(
          targetKey: sortKey,
          title: 'الترتيب',
          body: '«القريب» يحتاج موقعك من الإعدادات. «الخدمة المنزلية» للمختبرات التي تزورك.',
          align: OnboardingTooltipAlign.below,
        ),
        const OnboardingStep(
          title: 'اختر مختبراً',
          body: 'اضغط البطاقة لفتح التحاليل والباقات، ثم اختر التحليل واضغط حجز.',
        ),
      ];

  static List<OnboardingStep> analysesTour({
    required GlobalKey searchKey,
    required GlobalKey filterKey,
  }) =>
      [
        OnboardingStep(
          targetKey: searchKey,
          title: 'بحث التحاليل',
          body: 'ابحث بالاسم أو استخدم الفلاتر لتضييق النتائج.',
          align: OnboardingTooltipAlign.below,
        ),
        OnboardingStep(
          targetKey: filterKey,
          title: 'الفلترة والترتيب',
          body: 'صنّف حسب النوع أو السعر، ثم اضغط على التحليل.',
          align: OnboardingTooltipAlign.below,
        ),
        const OnboardingStep(
          title: 'الحجز',
          body: 'من صفحة التحليل اختر مختبراً يقدّم الخدمة ثم اضغط «حجز».',
        ),
      ];

  static const List<OnboardingStep> bookingsTour = [
    OnboardingStep(
      title: 'حجوزاتك',
      body:
          'هنا تظهر كل حجوزاتك. اضغط على حجز لعرض التفاصيل أو إكمال الدفع إن كان معلّقاً.',
    ),
  ];

  static const List<OnboardingStep> bookFlowTour = [
    OnboardingStep(
      title: 'خطوات الحجز (1/4)',
      body: 'اختر «في المختبر» أو «خدمة منزلية» حسب ما يوفّره المختبر.',
    ),
    OnboardingStep(
      title: 'خطوات الحجز (2/4)',
      body: 'اختر التاريخ من التقويم، ثم الفترة الزمنية المتاحة (صباحاً، مساءً، …).',
    ),
    OnboardingStep(
      title: 'خطوات الحجز (3/4)',
      body: 'راجع الملخص والسعر. للمنزل أدخل العنوان بدقة.',
    ),
    OnboardingStep(
      title: 'خطوات الحجز (4/4)',
      body: 'بعد التأكيد ادفع عبر البوابة الإلكترونية. ستصلك حالة الحجز في «حجوزاتي».',
    ),
  ];

  static const List<Map<String, String>> bookingGuideSections = [
    {
      'title': '١. اختر التحليل أو المختبر',
      'body':
          'من الرئيسية ابحث عن تحليل، أو من «المختبرات» اختر مختبراً قريباً منك.',
    },
    {
      'title': '٢. تأكد من المنطقة',
      'body': 'في المختبرات استخدم فلتر المنطقة أو «القريب» بعد حفظ موقعك في الإعدادات.',
    },
    {
      'title': '٣. اختر نوع الزيارة',
      'body': '«في المختبر» للحضور للفرع، أو «خدمة منزلية» إن كان المختبر يوفرها.',
    },
    {
      'title': '٤. الموعد والدفع',
      'body': 'اختر اليوم والفترة، راجع السعر، ثم أكّد وادفع. يمكنك متابعة الحجز من تبويب حجوزاتي.',
    },
    {
      'title': '٥. تحتاج مساعدة؟',
      'body': 'اضغط زر المساعدة ؟ في أعلى الشاشة أو المحادثة مع المساعد في الأسفل.',
    },
  ];
}

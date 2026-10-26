import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/features/bookings/screens/booking_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _booking(Map<String, dynamic> extra) => {
      'id': 1,
      'booking_number': 'BK-TEST',
      'service_name_ar': 'تحليل دم',
      'provider_name_ar': 'مختبر',
      'booking_date': '2026-10-30',
      'service_price': 100,
      'total_amount': 115,
      ...extra,
    };

Future<void> _pump(WidgetTester tester, Map<String, dynamic> booking) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppSettingsProvider(),
      child: MaterialApp(home: BookingDetailScreen(booking: booking)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('paid booking shows "request cancellation" and requires a reason', (tester) async {
    await _pump(tester, _booking({'status': 'confirmed', 'payment_status': 'paid', 'can_cancel': true}));
    expect(find.text('طلب إلغاء الحجز'), findsOneWidget);

    await tester.tap(find.text('طلب إلغاء الحجز'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('سبب الإلغاء (مطلوب)'), findsOneWidget);

    await tester.tap(find.text('إرسال الطلب'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('اكتب سبب الإلغاء بوضوح'), findsOneWidget);
  });

  testWidgets('pending request hides cancel button and shows status', (tester) async {
    await _pump(tester, _booking({
      'status': 'confirmed',
      'payment_status': 'paid',
      'can_cancel': false,
      'cancellation_request': {'status': 'pending', 'reason': 'x'},
    }));
    expect(find.text('طلب الإلغاء قيد المراجعة'), findsOneWidget);
    expect(find.text('طلب إلغاء الحجز'), findsNothing);
  });

  testWidgets('rejected request shows admin note', (tester) async {
    await _pump(tester, _booking({
      'status': 'confirmed',
      'payment_status': 'paid',
      'can_cancel': true,
      'cancellation_request': {'status': 'rejected', 'admin_note': 'الموعد غداً'},
    }));
    expect(find.text('رُفض طلب الإلغاء والحجز ما زال قائماً'), findsOneWidget);
    expect(find.text('الموعد غداً'), findsOneWidget);
  });

  testWidgets('refund in progress', (tester) async {
    await _pump(tester, _booking({
      'status': 'cancelled',
      'payment_status': 'paid',
      'refund': {'status': 'requested', 'amount': 115},
    }));
    expect(find.text('جارٍ استرداد المبلغ إلى وسيلة الدفع'), findsOneWidget);
  });

  testWidgets('refund done', (tester) async {
    await _pump(tester, _booking({
      'id': 2,
      'status': 'cancelled',
      'payment_status': 'paid',
      'refund': {'status': 'processed', 'amount': 115},
    }));
    expect(find.text('تم استرداد المبلغ'), findsOneWidget);
  });

  testWidgets('booking for another person shows the patient name', (tester) async {
    await _pump(tester, _booking({'status': 'confirmed', 'payment_status': 'paid', 'patient_name': 'أحمد محمد'}));
    expect(find.text('لمن هذا التحليل؟'), findsOneWidget);
    expect(find.text('أحمد محمد'), findsOneWidget);
  });

  testWidgets('unpaid booking keeps immediate cancel with optional reason', (tester) async {
    await _pump(tester, _booking({'status': 'pending', 'payment_status': 'pending', 'can_cancel': true}));
    expect(find.text('إلغاء الحجز'), findsOneWidget);
    await tester.tap(find.text('إلغاء الحجز'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('سبب الإلغاء (اختياري)'), findsOneWidget);
    expect(find.text('نعم، إلغاء'), findsOneWidget);
  });
}

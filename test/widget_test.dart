// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:rast/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RastApp());
    await tester.pump();
    expect(find.text('راست'), findsOneWidget);
    // إنهاء مؤقتات flutter_animate في شاشة الـ splash قبل انتهاء الاختبار.
    await tester.pump(const Duration(seconds: 2));
  });
}

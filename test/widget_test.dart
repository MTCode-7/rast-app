// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:rast/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RastApp());
    await tester.pumpAndSettle();
    expect(find.text('راست'), findsOneWidget);
  });
}

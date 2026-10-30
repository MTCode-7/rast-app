import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/widgets/fly_to_cart.dart';
import 'package:rast/core/widgets/rast_motion.dart';

void main() {
  testWidgets('العنصر يطير إلى أيقونة السلة والعداد لا يزيد إلا عند الهبوط', (tester) async {
    final sourceKey = GlobalKey();
    final targetKey = GlobalKey();
    FlyToCart.registerTarget(targetKey);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned(left: 20, bottom: 40, child: SizedBox(key: sourceKey, width: 120, height: 50)),
          Positioned(right: 16, top: 30, child: SizedBox(key: targetKey, width: 40, height: 40)),
        ]),
      ),
    ));

    final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
    final landedBefore = FlyToCart.landed.value;
    final from = FlyToCart.rectOf(sourceKey);
    expect(from, isNotNull);

    final flight = FlyToCart.run(overlay: overlay, from: from, delay: const Duration(milliseconds: 100));
    await tester.pump();
    expect(FlyToCart.pending.value, 1, reason: 'العداد معلّق أثناء الطيران');

    await tester.pump(const Duration(milliseconds: 150)); // بعد مهلة الانطلاق
    await tester.pump(const Duration(milliseconds: 500)); // منتصف الطيران
    expect(FlyToCart.pending.value, 1);
    expect(FlyToCart.landed.value, landedBefore);

    await tester.pump(const Duration(milliseconds: 500)); // هبط
    expect(FlyToCart.pending.value, 0);
    expect(FlyToCart.landed.value, landedBefore + 1);

    await tester.pumpAndSettle();
    await flight;
    FlyToCart.unregisterTarget(targetKey);
  });

  testWidgets('قلب المفضلة ينبض عند التفعيل دون أخطاء', (tester) async {
    Widget heart(bool active) => MaterialApp(home: Center(child: AnimatedFavoriteIcon(active: active)));
    await tester.pumpWidget(heart(false));
    await tester.pumpWidget(heart(true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('احتفال النجاح يظهر ويختفي وحده', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(onPressed: () => Celebration.show(context), child: const Text('go'));
    })));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
  });
}

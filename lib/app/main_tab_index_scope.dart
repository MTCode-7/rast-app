import 'package:flutter/material.dart';

/// يُبلّغ الشاشات داخل [IndexedStack] عن التبويب النشط في [MainScaffold].
class MainTabIndexScope extends InheritedWidget {
  const MainTabIndexScope({
    super.key,
    required this.currentIndex,
    required super.child,
  });

  final int currentIndex;

  static MainTabIndexScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MainTabIndexScope>();
    assert(scope != null, 'MainTabIndexScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(MainTabIndexScope oldWidget) =>
      oldWidget.currentIndex != currentIndex;
}

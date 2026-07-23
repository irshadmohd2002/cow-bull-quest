import 'package:cowbullgame/widgets/cow_head_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders at the requested size without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CowHeadIcon(size: 24, color: Colors.brown)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(CowHeadIcon)), const Size(24, 24));
  });

  testWidgets('renders at small badge-icon sizes without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CowHeadIcon(size: 12))),
    );

    expect(tester.takeException(), isNull);
  });
}

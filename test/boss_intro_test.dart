import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrimap_us/screens/boss_intro_card.dart';

void main() {
  testWidgets('ボスの登場カード: 名前・物語の種類・事実の注記が出て、タップで閉じる', (t) async {
    var closed = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BossIntroCard(title: 'Boss: Water Nymph', basisLabel: 'Legend', fact: 'The rock is real. The siren is a legend.', onClose: () => closed++),
      ),
    ));
    expect(find.text('Boss: Water Nymph'), findsOneWidget);
    expect(find.text('Legend'), findsOneWidget);
    expect(find.text('The rock is real. The siren is a legend.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('boss-intro')));
    expect(closed, 1);
  });

  testWidgets('事実の注記が空でも崩れない', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: BossIntroCard(title: 'Boss', basisLabel: 'History', fact: '', onClose: () {}))));
    expect(find.text('Boss'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrimap_us/screens/result_dialog.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: Builder(builder: (context) => Center(child: ElevatedButton(onPressed: () => showDialog<void>(context: context, builder: (_) => child), child: const Text('open'))))),
    );

void main() {
  test('星の数: 負けは0、勝ちは1、拠点の耐久が半分以上で2、満タンで3', () {
    expect(resultStars(won: false, baseHp: 15, maxHp: 15), 0);
    expect(resultStars(won: true, baseHp: 1, maxHp: 15), 1);
    expect(resultStars(won: true, baseHp: 7, maxHp: 15), 1);
    expect(resultStars(won: true, baseHp: 8, maxHp: 15), 2);
    expect(resultStars(won: true, baseHp: 15, maxHp: 15), 3);
  });

  testWidgets('勝利: タイトル・星・スコア・ボタンが出て、押せる', (t) async {
    var back = 0;
    await t.pumpWidget(_host(ResultDialog(
      won: true,
      title: 'VICTORY',
      stars: 3,
      score: 1234,
      scoreText: (n) => 'Score: $n',
      subtitle: 'Waves cleared: 5',
      extra: 'New best!',
      secondary: [TextButton(onPressed: () {}, child: const Text('Share'))],
      primary: [FilledButton(onPressed: () => back++, child: const Text('Again'))],
    )));
    await t.tap(find.text('open'));
    await t.pumpAndSettle(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 5));
    expect(find.text('VICTORY'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.text('Score: 1234'), findsOneWidget);
    expect(find.text('New best!'), findsOneWidget);
    await t.tap(find.text('Again'));
    expect(back, 1);
  });

  testWidgets('敗北: 星は出ず、長いタイトルでも1行に収まる', (t) async {
    await t.pumpWidget(_host(ResultDialog(
      won: false,
      title: '州都が陥落しました。',
      stars: 0,
      score: 0,
      scoreText: (n) => 'スコア: $n',
      subtitle: 'クリアしたウェーブ: 1',
      primary: [FilledButton(onPressed: () {}, child: const Text('もう一度'))],
    )));
    await t.tap(find.text('open'));
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.text('州都が陥落しました。'), findsOneWidget);
    expect(tester(t), isNull);
  });
}

Object? tester(WidgetTester t) => t.takeException();

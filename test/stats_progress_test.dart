import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/screens/stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('統計: クイズの週ごとの棒グラフと、苦手な州（未習得を先に）が出て、そこから復習を始められる', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    app.today = () => '2026-10-19';
    final ids = app.pack.regions.map((r) => r.id).toList();
    await t.pumpWidget(MaterialApp(home: StatsScreen(app: app)));
    expect(find.byKey(const ValueKey('trend-empty')), findsOneWidget); // まだ解いていない
    expect(find.byKey(const ValueKey('weak-none')), findsOneWidget);

    await t.runAsync(() async {
      await app.record(ids[0], correct: false);
      await app.record(ids[0], correct: false);
      await app.record(ids[1], correct: false);
      await app.record(ids[2], correct: true);
      await app.record(ids[1], correct: true); // ids[1] は習得済みになる（ミスの記録は残る）
    });
    expect(app.quizHistory.totalAnswers, 5);
    expect(app.weakRegions.map((w) => w.id).toList(), [ids[0], ids[1]]); // 未習得の ids[0] が先
    expect(app.weakRegions[1].mastered, true);

    await t.pumpWidget(MaterialApp(home: StatsScreen(app: app)));
    expect(find.byKey(const ValueKey('trend-empty')), findsNothing);
    expect(find.byKey(const ValueKey('trend-bar-7')), findsOneWidget); // 今週
    expect(find.byKey(ValueKey('weak-${ids[0]}')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const ValueKey('weak-review')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const ValueKey('weak-review')));
    await t.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget); // 復習のクイズが始まる
    await t.pumpWidget(const SizedBox());
  });
}

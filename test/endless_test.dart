import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/leaderboard.dart';
import 'package:terrimap_us/monetization.dart';
import 'package:terrimap_us/screens/endless_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('自己ベストを更新したときだけ保存し、ランキングへ送る。下回る結果は何もしない', () async {
    final app = await AppState.load();
    final lb = RecordingLeaderboard();
    app.leaderboard = lb;
    final id = app.pack.regions.first.id;
    expect(await app.recordEndless(id, 0, 500), isFalse); // 1波も守れない
    expect(await app.recordEndless(id, 6, 1200), isTrue);
    expect(await app.recordEndless(id, 5, 99999), isFalse);
    expect(await app.recordEndless(id, 7, 10), isTrue);
    expect(lb.sent, [6 * 1000000 + 1200, 7 * 1000000 + 10]);
    expect((await AppState.load()).endless.bestOf(id)!.waves, 7); // 再起動しても残る
  });

  testWidgets('エンドレス画面: 州の一覧に自己ベストが出て、無料の州はバトルが始まる', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await app.setTutorialDone(true);
    await t.runAsync(() => app.recordEndless('US-CA', 4, 300));
    await t.pumpWidget(ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(Monetization.fakeEntitlement()),
        optionalAdGateProvider.overrideWithValue(null),
      ],
      child: MaterialApp(home: EndlessScreen(app: app, premium: false)),
    ));
    await t.pump();
    expect(find.text('Best: 4 waves'), findsWidgets); // 一覧と、今日の州(たまたま同じ州のとき)
    // 記録のある州が先頭
    // 名前順ならAlaskaが先だが、記録のあるCaliforniaが上に来る
    expect(t.getTopLeft(find.byKey(const ValueKey('endless-US-CA'))).dy, lessThan(t.getTopLeft(find.byKey(const ValueKey('endless-US-AK'))).dy));
    await t.tap(find.byKey(const ValueKey('endless-US-CA')));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
    expect(find.text('Wave 0/30'), findsOneWidget);
  });

  testWidgets('エンドレス画面: 今日の州と、続きの章(守った波数で解ける)', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await t.runAsync(() => app.recordEndless('US-CA', 12, 300));
    await t.pumpWidget(MaterialApp(home: EndlessScreen(app: app, premium: false)));
    await t.pump();
    expect(find.byKey(const ValueKey('endless-today')), findsOneWidget);
    expect(find.textContaining("Today's state"), findsOneWidget);
    // 12波まで守った: 10波の章は読め、20・30波は鍵つき
    expect(find.text('Reach 20 waves to read'), findsOneWidget);
    expect(find.text('Reach 30 waves to read'), findsOneWidget);
    expect(find.text('Reach 10 waves to read'), findsNothing);
    await t.tap(find.byKey(const ValueKey('epilogue-10')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('story-line')), findsOneWidget);
  });

  test('結果の共有文: アプリ名・州・波数・スコアが入る', () async {
    final app = await AppState.load();
    await app.setLang('en');
    final txt = app.endlessShareText('US-CA', 14, 2500);
    expect(txt, contains('14'));
    expect(txt, contains('2500'));
    expect(txt, contains(app.s.regionName('US-CA')));
    expect(txt, isNot(contains('{')));
  });
}

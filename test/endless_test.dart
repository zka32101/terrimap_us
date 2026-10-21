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
    expect(find.text('Best: 4 waves'), findsOneWidget);
    // 記録のある州が先頭
    final first = t.widget<ListTile>(find.byType(ListTile).first);
    expect(first.key, const ValueKey('endless-US-CA'));
    await t.tap(find.byKey(const ValueKey('endless-US-CA')));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
    expect(find.text('Wave 0/30'), findsOneWidget);
  });
}

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/progress/region_progress.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/main.dart';
import 'package:terrimap_us/monetization.dart';
import 'package:terrimap_us/screens/quiz_screen.dart';
import 'package:terrimap_us/screens/stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('色覚に配慮: 初期はオフ（緑と赤）。オンにすると青とオレンジになり、再起動しても残る', () async {
    final app = await AppState.load();
    expect(app.colorBlind, false);
    expect(app.palette.region(RegionState.mastered), defaultRegionColor(RegionState.mastered));
    await app.setColorBlind(true);
    expect(app.palette.region(RegionState.mastered), colorBlindRegionColor(RegionState.mastered));
    expect(app.palette.region(RegionState.missed), colorBlindRegionColor(RegionState.missed));
    expect(app.palette.mapOk, answerCorrectColor(colorBlind: true));
    expect(app.palette.choiceOk == app.palette.choiceNg, false);
    expect((await AppState.load()).colorBlind, true);
  });

  // 端末の文字サイズを大きくしても、主な画面が崩れない（はみ出しがない）。
  for (final scale in [1.5, 2.0]) {
    testWidgets('文字サイズ $scale倍: ホーム・クイズ・統計がはみ出さない', (t) async {
      await t.binding.setSurfaceSize(const Size(400, 800));
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        t.binding.setSurfaceSize(null);
        t.platformDispatcher.clearAllTestValues();
      });
      final app = await t.runAsync(AppState.load) as AppState;
      await app.setLang('en');
      await t.pumpWidget(ProviderScope(
        overrides: [
          entitlementServiceProvider.overrideWithValue(Monetization.fakeEntitlement()),
          optionalAdGateProvider.overrideWithValue(null),
        ],
        child: TerrimapApp(app: app),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull, reason: 'ホーム');

      final qs = QuizEngine(app.pack, seed: 1).generate(count: 3, types: QuestionType.values);
      await t.pumpWidget(MaterialApp(home: QuizScreen(app: app, questions: qs)));
      await t.pump();
      expect(t.takeException(), isNull, reason: 'クイズ');

      await t.pumpWidget(MaterialApp(home: StatsScreen(app: app)));
      await t.pump();
      expect(t.takeException(), isNull, reason: '統計');
    });
  }
}

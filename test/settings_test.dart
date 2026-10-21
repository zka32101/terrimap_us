import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/main.dart';
import 'package:terrimap_us/monetization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appThemeMode.value = ThemeMode.system;
  });

  Future<AppState> openSettings(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
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
    await t.tap(find.byIcon(Icons.settings));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    return app;
  }

  Future<void> reveal(WidgetTester t, Finder f) => t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);

  testWidgets('設定: 共通の項目（表示モード・言語・データ削除・このアプリについて）と、固有の項目（クイズ連動）が並ぶ', (t) async {
    final app = await openSettings(t);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    await reveal(t, find.text('Delete my data'));
    expect(find.text('Delete my data'), findsOneWidget);
    await reveal(t, find.text('About this app'));
    expect(find.text('About this app'), findsOneWidget);
    expect(find.text(app.ui.t('assist.setting')), findsWidgets);
    expect(find.text('Privacy policy'), findsNothing); // URL を設定するまで出ない
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('設定: 「チュートリアルをもう一度見る」で、案内が戻る', (t) async {
    final app = await openSettings(t);
    await t.runAsync(() => app.setTutorialDone(true));
    expect(app.tutorialDone, isTrue);
    await t.ensureVisible(find.byKey(const ValueKey('tutorial-replay')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('tutorial-replay')));
    await t.pump();
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    expect(app.tutorialDone, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('設定: 表示モードを変えると全体に反映され、言語とクイズ連動も変えられる', (t) async {
    final app = await openSettings(t);
    await t.tap(find.text('Dark'));
    await t.pump();
    expect(appThemeMode.value, ThemeMode.dark);
    expect(t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    await t.tap(find.text('Deutsch'));
    await t.pump();
    expect(app.lang, 'de');
    await reveal(t, find.byKey(const ValueKey('assist-switch')));
    await t.ensureVisible(find.byKey(const ValueKey('assist-switch')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('assist-switch')));
    await t.pump();
    expect(app.quizAssist, false);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('設定: データを削除すると、進捗・バトルの記録・設定が初期に戻る', (t) async {
    final app = await openSettings(t);
    await t.runAsync(() async {
      await app.recordBattleClear(StageKind.normal, 'US-CA', Difficulty.easy);
      await app.record('US-CA', correct: true);
    });
    await t.pump();
    expect(app.battle.isCleared(StageKind.normal, 'US-CA'), true);
    await reveal(t, find.text('Delete my data'));
    // ポリシーへのリンクが増えて、画面の下にはみ出すので、見える位置までスクロールしてから押す。
    await t.ensureVisible(find.text('Delete my data'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete my data'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byType(Checkbox));
    await t.pump();
    await t.tap(find.text('Delete'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(app.battle.isCleared(StageKind.normal, 'US-CA'), false);
    expect(app.lang, 'en'); // 端末の言語（テストでは英語）に戻る
    expect(app.quizAssist, true);
    expect(find.text('Delete my data'), findsNothing); // 設定画面を閉じて、ホームへ戻る
    await t.pumpWidget(const SizedBox());
  });
}

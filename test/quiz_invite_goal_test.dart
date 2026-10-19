import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/daily/quiz_invite.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/main.dart';
import 'package:terrimap_us/monetization.dart';
import 'package:terrimap_us/screens/stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(WidgetTester t, AppState app) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(Monetization.fakeEntitlement()),
        optionalAdGateProvider.overrideWithValue(null),
      ],
      child: TerrimapApp(app: app),
    ));
    await t.pump();
  }

  testWidgets('週間目標: 今週の問題数が出て、目標を変えると残り、達成すると表示が出る', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    app.today = () => '2026-10-19';
    final id = app.pack.regions.first.id;
    await t.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await app.record(id, correct: i.isEven);
      }
    });
    await t.pumpWidget(MaterialApp(home: StatsScreen(app: app)));
    expect(find.text('3 of 50 questions this week'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-reached')), findsNothing);
    await t.tap(find.byKey(const ValueKey('goal-20')));
    await t.pump();
    expect(app.weeklyGoalTarget, 20);
    expect(find.text('3 of 20 questions this week'), findsOneWidget);
    expect((await t.runAsync(AppState.load) as AppState).weeklyGoalTarget, 20); // 再起動しても残る
    await app.setWeeklyGoalTarget(20);
    await t.runAsync(() async {
      for (var i = 0; i < 17; i++) {
        await app.record(id, correct: true);
      }
    });
    await t.pumpWidget(MaterialApp(home: StatsScreen(app: app)));
    expect(find.byKey(const ValueKey('goal-reached')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('挑戦状: 「友だちに挑戦状」で5問のクイズが始まる', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await pumpHome(t, app);
    await t.tap(find.byKey(const ValueKey('qinvite-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('qinvite-send')));
    await t.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('挑戦状を受け取る: 正しいコードだけ開始でき、壊れたコードや別の国のコードは弾く', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await pumpHome(t, app);
    await t.tap(find.byKey(const ValueKey('qinvite-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('qinvite-enter')));
    await t.pumpAndSettle();
    TextButton start() => t.widget<TextButton>(find.byKey(const ValueKey('qinvite-start')));
    expect(start().onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('qinvite-field')), 'TMQ1.other.123.5.s3');
    await t.pump();
    expect(find.byKey(const ValueKey('qinvite-invalid')), findsOneWidget);
    expect(start().onPressed, isNull);
    final code = QuizInvite(packId: app.pack.packId, seed: 4242, count: 5, score: 3).toCode();
    await t.enterText(find.byKey(const ValueKey('qinvite-field')), 'どうぞ $code');
    await t.pump();
    expect(find.byKey(const ValueKey('qinvite-invalid')), findsNothing);
    await t.tap(find.byKey(const ValueKey('qinvite-start')));
    await t.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}

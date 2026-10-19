import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/main.dart';
import 'package:terrimap_us/monetization.dart';
import 'package:terrimap_us/screens/daily_landmark_card.dart';
import 'package:terrimap_us/screens/landmark_quiz_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('名所クイズ: ホームのボタンから、名所の問題だけが出る', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    expect(app.landmarkRegionIds, isNotEmpty);
    await t.pumpWidget(ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(Monetization.fakeEntitlement()),
        optionalAdGateProvider.overrideWithValue(null),
      ],
      child: TerrimapApp(app: app),
    ));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('landmark-quiz')));
    await t.pumpAndSettle();
    expect(find.textContaining(app.s.t('landmarkOf')), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('名所クイズの結果: 間違えた名所が名前と州つきで並び、正答率が出る。全問正解なら称える', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    final qs = QuizEngine(app.pack, seed: 3).generate(count: 4, types: const [QuestionType.landmarkOf]);
    Future<void> show(List<bool> r) => t.pumpWidget(MaterialApp(
        home: Scaffold(body: LandmarkQuizSummary(app: app, results: r, questions: qs))));
    await show([true, false, false, true]);
    expect(find.textContaining('2 / 4'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
    expect(find.byKey(const ValueKey('landmark-missed-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('landmark-missed-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('landmark-missed-2')), findsNothing);
    expect(find.textContaining('${app.landmarkName(qs[1].subjectId)} · ${app.s.regionName(qs[1].correctId)}'), findsOneWidget);
    await show([true, true, true, true]);
    expect(find.byKey(const ValueKey('landmark-perfect')), findsOneWidget);
    expect(find.byKey(const ValueKey('landmark-missed-0')), findsNothing);
  });

  testWidgets('名所の詳細: 今日の名所カードをタップすると、名前と州が出る', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    app.today = () => '2026-10-19';
    await t.pumpWidget(MaterialApp(home: Scaffold(body: DailyLandmarkCard(app: app, art: const ArtSet()))));
    await t.tap(find.byKey(const ValueKey('daily-landmark')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('landmark-detail')), findsOneWidget);
    expect(find.textContaining('Located in'), findsOneWidget);
  });
}

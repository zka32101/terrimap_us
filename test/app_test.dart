import 'dart:io';

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/pack/pack_validator.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/main.dart';
import 'package:terrimap_us/monetization.dart';
import 'package:terrimap_us/screens/quiz_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('同梱の米国packは検証を通る', () {
    String r(String f) => File('packs/us/$f').readAsStringSync();
    expect(
      PackValidator.validate(
        packJson: r('pack.json'),
        regionsJson: r('regions.json'),
        geoJson: r('geo.geojson'),
        stringsJsonByLang: {'en': r('strings/en.json'), 'ja': r('strings/ja.json'), 'fr': r('strings/fr.json'), 'es': r('strings/es.json'), 'it': r('strings/it.json'), 'pt': r('strings/pt.json'), 'nl': r('strings/nl.json'), 'tr': r('strings/tr.json'), 'ko': r('strings/ko.json'), 'zh': r('strings/zh.json')},
      ),
      isEmpty,
    );
  });

  test('AppState: 51州を読み込み、進捗は保存されて再起動後も残る', () async {
    final a = await AppState.load();
    expect(a.pack.regions, hasLength(51));
    expect(a.progress.masteredCount, 0);
    await a.record('US-CA', correct: true);
    await a.record('US-NY', correct: false);

    final b = await AppState.load(); // 再起動を模す
    expect(b.progress.masteredCount, 1);
    expect(b.progress.stateOf('US-NY').name, 'missed');
  });

  test('地域名・州都名が引ける', () async {
    final a = await AppState.load();
    expect(a.s.regionName('US-CA'), 'California');
    expect(a.s.capitalName('US-CA'), 'Sacramento');
  });

  testWidgets('ホーム→クイズ: ホームが表示され、クイズ画面に進める', (t) async {
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
    expect(find.text('State Master – USA'), findsOneWidget);
    expect(find.text('0 / 51'), findsOneWidget);
    expect(find.byKey(const Key('zoom_in')), findsOneWidget); // 極小の州(DC・RI等)を押せるよう拡大ボタン

    await t.tap(find.text('Quiz'));
    await t.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget);
  });

  testWidgets('QuizScreen: 4択を押すと結果が出て、次へ進める', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    final qs = QuizEngine(app.pack, seed: 5).generate(count: 2, types: [QuestionType.nameFromMap]);
    List<bool>? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => result = await Navigator.of(ctx)
              .push<List<bool>>(MaterialPageRoute(builder: (_) => QuizScreen(app: app, questions: qs))),
          child: const Text('go'),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();

    final correct = app.s.regionName(qs[0].correctId);
    await t.tap(find.text(correct));
    await t.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);
    // 答え合わせから、その州の解説ページを開ける
    await t.tap(find.byKey(const ValueKey('quiz-guide')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-blurb')), findsOneWidget);
    Navigator.of(t.element(find.byKey(const ValueKey('guide-blurb')))).pop();
    await t.pumpAndSettle();
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await t.tap(find.text(app.s.regionName(qs[1].correctId)));
    await t.pumpAndSettle();
    await t.tap(find.text('Finish'));
    await t.pumpAndSettle();
    expect(result, [true, true]);
    expect(app.progress.masteredCount, 2);
  });

  testWidgets('QuizScreen: 隣接の問題 — 「接している州」を選べて、正解の隣が分かる。間違いは不正解になる', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    final qs = QuizEngine(app.pack, seed: 5).generate(count: 2, types: [QuestionType.neighborOf]);
    expect(qs.every((q) => q.type == QuestionType.neighborOf), true);
    List<bool>? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => result = await Navigator.of(ctx)
              .push<List<bool>>(MaterialPageRoute(builder: (_) => QuizScreen(app: app, questions: qs))),
          child: const Text('go'),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.textContaining('Which state borders this one?'), findsOneWidget);
    expect(find.textContaining(app.s.regionName(qs[0].targetId)), findsWidgets); // 対象の州の名前が問題に出る

    await t.tap(find.text(app.s.regionName(qs[0].correctId)));
    await t.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    final wrong = qs[1].choiceIds.firstWhere((id) => id != qs[1].correctId);
    await t.tap(find.text(app.s.regionName(wrong)));
    await t.pumpAndSettle();
    expect(find.textContaining('Answer: ${app.s.regionName(qs[1].correctId)}'), findsOneWidget);
    await t.tap(find.text('Finish'));
    await t.pumpAndSettle();
    expect(result, [true, false]);
  });

  test('隣接の問題の文言は英語にある', () async {
    final app = await AppState.load();
    await app.setLang('en');
    expect(app.s.t('neighborOf'), 'Which state borders this one?');
  });

  testWidgets('QuizScreen: 名所の問題 — 名所の名前が出て、その州を選ぶと正解。間違えると不正解', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    expect(app.pack.facts, isNotNull);
    final qs = QuizEngine(app.pack, seed: 5).generate(count: 2, types: [QuestionType.landmarkOf]);
    expect(qs.every((q) => q.type == QuestionType.landmarkOf && q.subjectId != null), true);
    List<bool>? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => result = await Navigator.of(ctx)
              .push<List<bool>>(MaterialPageRoute(builder: (_) => QuizScreen(app: app, questions: qs))),
          child: const Text('go'),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.textContaining('In which state is this landmark?'), findsOneWidget);
    expect(find.textContaining(app.landmarkName(qs[0].subjectId)), findsOneWidget); // 名所の名前が問題に出る

    await t.tap(find.text(app.s.regionName(qs[0].correctId)));
    await t.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    final wrong = qs[1].choiceIds.firstWhere((id) => id != qs[1].correctId);
    await t.tap(find.text(app.s.regionName(wrong)));
    await t.pumpAndSettle();
    await t.tap(find.text('Finish'));
    await t.pumpAndSettle();
    expect(result, [true, false]);
  });
}

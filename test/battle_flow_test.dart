import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle/battle_engine.dart';
import 'package:terrimap_core/battle/replay.dart';
import 'package:terrimap_core/battle/daily_battle.dart';
import 'package:terrimap_core/battle/bot.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/battle/stage_generator.dart';
import 'package:terrimap_core/battle_ui/battle_view.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/main.dart';
import 'package:terrimap_us/monetization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AppState: 国の特性と、画面の文言（英語）を読み込む。足りない言語は英語になる', () async {
    final a = await AppState.load();
    expect(a.pack.profile, isNotNull);
    expect(a.pack.regions.any((r) => r.neighbors.isNotEmpty), true);
    expect(a.ui.t('hud.wave', {'n': 1, 'total': 5}), 'Wave 1/5');
    await a.setLang('fr'); // 翻訳がまだなくても動く
    expect(a.ui.t('hud.base'), 'Base');
    expect(a.ui.t('exclusive.name.tech_campus'), 'Tech Campus'); // 限定施設の名前も文言から
    expect(a.quizAssist, true);
    await a.setQuizAssist(false);
    expect((await AppState.load()).quizAssist, false);
  });

  Future<AppState> boot(WidgetTester t, {bool assist = true}) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await app.setQuizAssist(assist);
    await t.pumpWidget(ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(Monetization.fakeEntitlement()),
        optionalAdGateProvider.overrideWithValue(null),
      ],
      child: TerrimapApp(app: app),
    ));
    await t.pump();
    return app;
  }

  Future<void> enterBattle(WidgetTester t, String regionName) async {
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.ensureVisible(find.text(regionName));
    await t.pump();
    await t.tap(find.text(regionName));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  int coins(WidgetTester t) => int.parse((t.widget(find.byKey(const ValueKey('hud-coins'))) as Text).data!.replaceAll('● ', ''));

  Future<void> tapCell(WidgetTester t, int col, int row, int cols, int rows) async {
    final box = t.getRect(find.byKey(const ValueKey('board')));
    final l = BattleView.layout(box.size, cols, rows);
    await t.tapAt(box.topLeft + Offset(l.dx + (col + 0.5) * l.cell, l.dy + (row + 0.5) * l.cell));
    await t.pump();
  }

  testWidgets('モード切替: 地方決戦は買い切り＋過半数クリア、エクストラは全州hardクリアで解放。題材と事実の注記を見せる', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('modes')), findsOneWidget);

    await t.tap(find.text('Regions'));
    await t.pump();
    final g = app.pack.profile!.groups.values.first;
    expect(find.byKey(ValueKey('region-${g.id}')), findsOneWidget);
    expect(find.text('Unlock all states to play this stage.'), findsWidgets); // 無料版は買い切りが必要

    await t.tap(find.text('Extra'));
    await t.pump();
    final e = app.pack.profile!.extras.first;
    expect(find.byKey(ValueKey('extra-${e.id}')), findsOneWidget);
    expect(find.text('Unlock all states to play this stage.'), findsWidgets);
  });

  testWidgets('購入済み＋全州hardクリアのあとは、エクストラの説明（事実の注記つき）から始められる', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    for (final r in app.pack.regions) {
      await t.runAsync(() => app.recordBattleClear(StageKind.normal, r.id, Difficulty.hard));
    }
    final fake = Monetization.fakeEntitlement();
    await t.runAsync(() => fake.purchase(unlockProductId));
    await t.pumpWidget(ProviderScope(
      overrides: [entitlementServiceProvider.overrideWithValue(fake), optionalAdGateProvider.overrideWithValue(null)],
      child: TerrimapApp(app: app),
    ));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Extra'));
    await t.pump();
    final e = app.pack.profile!.extras.first;
    await t.tap(find.byKey(ValueKey('extra-${e.id}')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('extra-fact')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('extra-play')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
    expect(find.text('Wave 0/${e.waves}'), findsOneWidget);
  });

  Replay botReplay(AppState app, String id, Difficulty d) {
    final e = BattleEngine(StageGenerator(app.pack).generate(id, d), profile: app.pack.profile, pack: app.pack);
    final rec = ReplayRecorder(e);
    BattleBot(e, BotProfile.expert, recorder: rec).play();
    return rec.toReplay(packId: app.pack.packId, kind: StageKind.normal, stageId: id, difficulty: d);
  }

  test('今日のバトルの結果は端末に保存され、古い日は消える', () async {
    final a = await AppState.load();
    final r = botReplay(a, 'US-CA', Difficulty.easy);
    await a.saveDaily('2026-10-01', r);
    expect((await AppState.load()).dailyReplay('2026-10-01')!.result, r.result);
    for (var d = 2; d <= 10; d++) {
      await a.saveDaily('2026-10-${d.toString().padLeft(2, '0')}', r);
    }
    expect(a.dailyReplay('2026-10-01'), isNull); // 直近7日だけ
    expect(a.dailyReplay('2026-10-10'), isNotNull);
  });

  test('毎日のバトルの連続記録: 続けると増え、空くと戻り、端末に保存される。復習の重みは間違えた州が重い', () async {
    final a = await AppState.load();
    final r = botReplay(a, a.pack.regions.first.id, Difficulty.easy);
    a.today = () => '2026-10-02';
    expect(a.streak.currentOn(a.today()), 0);
    await a.saveDaily('2026-10-01', r);
    await a.saveDaily('2026-10-02', r);
    expect(a.streak.currentOn('2026-10-02'), 2);
    expect((await AppState.load()).streak.current, 2);
    expect(a.streak.currentOn('2026-10-05'), 0);
    final ids = a.pack.regions.map((x) => x.id).toList();
    await a.record(ids[0], correct: false);
    await a.record(ids[1], correct: true);
    final w = a.reviewWeights;
    expect(w[ids[0]]! > w[ids[2]]!, true);
    expect(w[ids[2]]! > w[ids[1]]!, true);
  });

  testWidgets('今日のバトル: 選択画面に出て、始められる。終えた日は完了になる。無料の間は無料の州から選ぶ', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    app.today = () => '2026-10-18';
    final d = DailyBattle.forDate(app.pack, '2026-10-18', allowedIds: freeRegionIds);
    expect(freeRegionIds, contains(d.stageId));
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Daily Battle'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('daily-battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
    Navigator.of(t.element(find.byKey(const ValueKey('hud-wave')))).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.runAsync(() => app.saveDaily('2026-10-18', botReplay(app, d.stageId, d.difficulty)));
    await t.pump();
    expect(find.text('You finished today\'s battle.', findRichText: false, skipOffstage: false), findsNothing); // 文は「完了 + 結果」と続くので部分一致で確かめる
    expect(find.textContaining('You finished today'), findsOneWidget);

    // 終えた日は、タップするとリプレイを見られる。最後まで飛ばすと、記録と一致したと出る
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('daily-battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('replay-board')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('replay-speed-4')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('replay-pause')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('replay-skip')));
    await t.pump();
    expect(find.byKey(const ValueKey('replay-done')), findsOneWidget);
    expect(find.textContaining('Verified'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('replay-restart')));
    await t.pump();
    expect(find.byKey(const ValueKey('replay-done')), findsNothing);
  });

  testWidgets('挑戦コード: 正しいコードは確かめられて遊べる。壊れたコードは遊べない', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    final code = botReplay(app, 'US-CA', Difficulty.easy).toShareCode();
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('challenge')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const ValueKey('challenge-code')), 'broken');
    await t.pump();
    expect(find.text('This replay could not be verified.'), findsOneWidget);
    expect((t.widget(find.byKey(const ValueKey('challenge-play'))) as FilledButton).onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('challenge-code')), code);
    await t.pump();
    expect(find.textContaining('California'), findsWidgets);
    // 見るだけもできる
    await t.tap(find.byKey(const ValueKey('challenge-watch')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('replay-board')), findsOneWidget);
    Navigator.of(t.element(find.byKey(const ValueKey('replay-board')))).pop();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('challenge')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const ValueKey('challenge-code')), code);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('challenge-play')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
  });

  testWidgets('ホーム→バトル→州を選ぶ→設置→波の開始→HUDが進む', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 740)); // 小さめのスマホ
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    await enterBattle(t, 'California');
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
    expect(find.text('Wave 0/5'), findsOneWidget);

    final stage = StageGenerator(app.pack).generate('US-CA', Difficulty.normal);
    final slot = stage.slots.first;
    final before = coins(t);
    await tapCell(t, slot.col, slot.row, stage.cols, stage.rows);
    expect(find.byKey(const ValueKey('place-farm')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('place-farm')));
    await t.pump();
    expect(coins(t), lessThan(before));
    expect(find.byKey(const ValueKey('upgrade')), findsOneWidget); // 施設が置かれ、操作欄に変わった

    await t.tap(find.byKey(const ValueKey('start-wave')));
    await t.pump();
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Wave 1/5'), findsOneWidget);
    expect(t.takeException(), isNull); // 小さい画面でもはみ出さない

    // 一時停止すると時間が進まない
    await t.tap(find.byKey(const ValueKey('pause')));
    await t.pump();
    final c = coins(t);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(coins(t), c);

    await t.pumpWidget(const SizedBox()); // 画面を閉じてタイマーを止める
  });

  testWidgets('クイズ連動: 正解するとスキルを3つから選べて、選ぶとHUDに出る', (t) async {
    final app = await boot(t);
    final stage = StageGenerator(app.pack).generate('US-CA', Difficulty.normal);
    final engine = BattleEngine(stage, profile: app.pack.profile, pack: app.pack, reviewWeights: app.reviewWeights);
    final q = engine.assistQuestion(engine.start())!;
    final correct = q.type == QuestionType.capitalFromName ? app.s.capitalName(q.correctId) : app.s.regionName(q.correctId);

    await enterBattle(t, 'California');
    await t.tap(find.byKey(const ValueKey('skill')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(correct));
    await t.pump();
    await t.pump(const Duration(seconds: 1)); // 結果の表示のあと閉じる
    await t.pump(const Duration(milliseconds: 400));
    final choice = find.byWidgetPredicate((w) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith('skill-'));
    expect(choice, findsNWidgets(3));
    await t.tap(choice.first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Active skill'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('無料でない州は、解放の案内が出る（バトルには入れない）', (t) async {
    await boot(t, assist: false);
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.scrollUntilVisible(find.byKey(const ValueKey('stage-US-VT')), 300, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    await t.ensureVisible(find.byKey(const ValueKey('stage-US-VT')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('stage-US-VT')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('hud-wave')), findsNothing);
    expect(find.text('Unlock all 51 states'), findsWidgets);
  });
}

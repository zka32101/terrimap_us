import 'dart:ui' as ui;
import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle/battle_engine.dart';
import 'package:terrimap_core/battle/replay.dart';
import 'package:terrimap_core/battle/bot.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/battle/invite.dart';
import 'package:terrimap_core/battle/stage_generator.dart';
import 'package:terrimap_core/battle/weekly_battle.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_core/battle_ui/battle_view.dart';
import 'package:terrimap_core/map/region_map_view.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';
import 'package:terrimap_us/a11y.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/screens/replay_screen.dart';
import 'package:terrimap_us/screens/achievements_screen.dart';
import 'package:terrimap_us/screens/collection_screen.dart';
import 'package:terrimap_us/screens/quiz_screen.dart';
import 'package:terrimap_us/screens/stats_screen.dart';
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
    await a.setLang('xx'); // 翻訳がない言語でも動く（英語になる）
    expect(a.ui.t('hud.base'), 'Base');
    expect(a.ui.t('exclusive.name.tech_campus'), 'Tech Campus'); // 限定施設の名前も文言から
    expect(a.quizAssist, true);
    await a.setQuizAssist(false);
    expect((await AppState.load()).quizAssist, false);
  });

  Future<AppState> boot(WidgetTester t, {bool assist = true, bool tutorial = false}) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await app.setTutorialDone(!tutorial); // 既定では案内を出さない（盤面の位置が動かないように）
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

  testWidgets('実績: クリアで達成され、画面で見られる（開くと NEW が既読になる）。ステージ選択から開ける', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 900));
    final app = await boot(t, assist: false);
    expect(app.achievements.unlockedCount, 0);
    expect(app.newAchievementCount, 0);
    await t.runAsync(() => app.recordBattleClear(StageKind.normal, app.pack.regions.first.id, Difficulty.easy));
    expect(app.achievements.unlockedIds, contains('firstClear'));
    expect(app.newAchievementCount, greaterThan(0));
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('achievements')), findsOneWidget);
    await t.pumpWidget(MaterialApp(home: AchievementsScreen(app: app)));
    await t.pump();
    expect(find.byKey(const ValueKey('ach-firstClear')), findsOneWidget);
    expect(find.text('First Victory'), findsOneWidget);
    expect(find.text('NEW'), findsWidgets);
    await t.pump();
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    expect(app.newAchievementCount, 0);
    expect((await t.runAsync(AppState.load) as AppState).seenAchievements, contains('firstClear'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('コレクション: 名所の画像があれば解放済みのカードに出る。画像が無い・未解放のカードはアイコンのまま', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    final all = app.pack.facts!.usable;
    final a = all.first;
    final b = all.firstWhere((l) => l.regionId == a.regionId && l.id != a.id, orElse: () => a);
    final locked = all.firstWhere((l) => l.regionId != a.regionId);
    await t.runAsync(() => app.recordBattleClear(StageKind.normal, a.regionId, Difficulty.easy));
    final img = (await t.runAsync(() async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = Colors.red);
      return rec.endRecording().toImage(8, 8);
    }))!;
    final art = ArtSet(images: {'landmarks/${a.id}': img, 'landmarks/${locked.id}': img});
    await t.pumpWidget(MaterialApp(home: CollectionScreen(app: app, art: art)));
    await t.pump();
    expect(find.byKey(ValueKey('card-image-${a.id}')), findsOneWidget); // 画像あり・解放済み
    if (b.id != a.id) expect(find.byKey(ValueKey('card-image-${b.id}')), findsNothing); // 解放済みだが画像なし → アイコン
    expect(find.byKey(ValueKey('card-image-${locked.id}')), findsNothing); // 未解放は、画像があっても出さない（鍵のまま）
    expect(t.takeException(), isNull); // はみ出しなし
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('コレクション: 州をクリアするとその州の名所カードが集まり、画面で見られる（開くと NEW が既読になる）', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 900));
    final app = await boot(t, assist: false);
    final first = app.pack.facts!.usable.first;
    final cardKey = ValueKey('card-${first.id}');
    expect(app.collection.unlockedCount, 0);
    expect(app.newCardCount, 0);
    await t.runAsync(() => app.recordBattleClear(StageKind.normal, first.regionId, Difficulty.easy));
    expect(app.collection.unlockedIds, contains(first.id));
    expect(app.newCardCount, greaterThan(0));
    await t.pumpWidget(MaterialApp(home: CollectionScreen(app: app)));
    await t.pump();
    expect(find.byKey(cardKey), findsOneWidget);
    expect(find.text(first.nameIn('en')), findsWidgets); // 解放したカードは名前が出る
    expect(find.text('NEW'), findsWidgets);
    await t.pump();
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    expect(app.newCardCount, 0); // 開いたので既読
    expect((await t.runAsync(AppState.load) as AppState).seenCards, contains(first.id)); // 端末に保存
    await t.pumpWidget(const SizedBox());
  });

  Future<void> enterBattle(WidgetTester t, String regionName) async {
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('stage-view-toggle'))); // 一覧に切り替える(地図のタップは別のテストで確かめる)
    await t.pump();
    await t.scrollUntilVisible(find.text(regionName), 200, scrollable: find.byType(Scrollable).last); // 州の一覧は、カードの下で長い
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

  test('バトルの連続記録: 続けると増え、空くと戻り、端末に保存される。復習の重みは間違えた州が重い', () async {
    final a = await AppState.load();
    a.today = () => '2026-10-02';
    expect(a.streak.currentOn(a.today()), 0);
    a.today = () => '2026-10-01';
    await a.recordBattleDay();
    a.today = () => '2026-10-02';
    await a.recordBattleDay();
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

  testWidgets('今日のバトルはない。選択画面は地図が初期で、難易度の切り替えは地図では出ない', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('daily-battle')), findsNothing);
    expect(find.text('Daily Battle'), findsNothing);
    expect(find.byKey(const ValueKey('stage-map')), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-legend')), findsWidgets); // ホームの下にも同じ凡例がある
    expect(find.byType(SegmentedButton<Difficulty>), findsNothing);
    expect(app.pack.regions, isNotEmpty);
  });

  testWidgets('地図で州を選ぶ: 無料の州をタップすると難易度の選択が出て、押すとその難易度で始まる。無料でない州は購入の案内', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await boot(t, assist: false);
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    final map = t.widget<RegionMapView>(find.byKey(const ValueKey('stage-map')));
    map.onTap!('US-VT'); // 無料でない州
    await t.pumpAndSettle();
    expect(find.text('Unlock all 51 states'), findsWidgets);
    expect(find.byKey(const ValueKey('stage-sheet-title')), findsNothing);
    Navigator.of(t.element(find.text('Unlock all 51 states').first)).pop();
    await t.pumpAndSettle();

    map.onTap!('US-CA');
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('stage-sheet-title')), findsOneWidget);
    expect(find.text('California'), findsWidgets);
    for (final d in Difficulty.values) {
      expect(find.byKey(ValueKey('play-US-CA-${d.name}')), findsOneWidget);
    }
    // 解説ページへ入れる(戻ると、シートは閉じている)
    await t.tap(find.byKey(const ValueKey('guide-US-CA')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-blurb')), findsOneWidget);
    Navigator.of(t.element(find.byKey(const ValueKey('guide-blurb')))).pop();
    await t.pumpAndSettle();
    map.onTap!('US-CA');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('play-US-CA-hard')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
  });

  testWidgets('地図の色: 初めは薄い灰色。クリアした一番むずかしい難易度の色になる。クイズで覚えても変わらない', (t) async {
    final app = await boot(t, assist: false);
    RegionMapView map() => t.widget<RegionMapView>(find.byType(RegionMapView));
    expect(map().colorOf('US-CA'), A11yPalette.clearColor(null));
    await t.runAsync(() => app.record('US-CA', correct: true)); // クイズで覚えた
    await t.pump();
    expect(map().colorOf('US-CA'), A11yPalette.clearColor(null)); // 色は変わらない
    await t.runAsync(() => app.recordBattleClear(StageKind.normal, 'US-CA', Difficulty.easy));
    await t.pump();
    expect(map().colorOf('US-CA'), A11yPalette.clearColor(Difficulty.easy));
    await t.runAsync(() => app.recordBattleClear(StageKind.normal, 'US-CA', Difficulty.hard));
    await t.runAsync(() => app.recordBattleClear(StageKind.normal, 'US-CA', Difficulty.normal));
    await t.pump();
    expect(app.bestClear('US-CA'), Difficulty.hard);
    expect(map().colorOf('US-CA'), A11yPalette.clearColor(Difficulty.hard));
    expect({for (final d in [null, ...Difficulty.values]) A11yPalette.clearColor(d)}.length, 4); // 4つとも違う色
    expect(find.byKey(const ValueKey('clear-legend')), findsOneWidget);
  });

  testWidgets('リプレイ: 最後まで飛ばすと、記録と一致したと出る。やり直せる', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    final r = botReplay(app, 'US-CA', Difficulty.easy);
    await t.pumpWidget(MaterialApp(home: ReplayScreen(app: app, replay: r)));
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

  testWidgets('今週のチャレンジ: 無料の間は無料の州。遊べて、終えると結果と共有が出て、もう挑戦できない。週が変わると新しくなる', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    app.today = () => '2026-10-20'; // 火曜
    final w = WeeklyBattle.forDate(app.pack, '2026-10-20', allowedIds: freeRegionIds);
    expect(w.kind, StageKind.normal);
    expect(freeRegionIds, contains(w.stageId));
    expect(app.weeklyRecord, isNull);
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text("This week's challenge"), findsOneWidget);
    expect(find.textContaining('6 days left'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('weekly-battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
    Navigator.of(t.element(find.byKey(const ValueKey('hud-wave')))).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.runAsync(() => app.saveWeekly(w.week, true, 14));
    await t.pump();
    expect(find.textContaining('Done this week: ✅ ♥14'), findsOneWidget);
    expect(find.byKey(const ValueKey('weekly-share')), findsOneWidget);
    // 終えたら、タップしても戦闘に入れない（やり直しは出来ない）
    expect(t.widget<ListTile>(find.byKey(const ValueKey('weekly-battle'))).onTap, isNull);
    // 共有の文面は、招待コード（結果つき）として読める
    final text = app.weeklyText(w, record: app.weeklyRecord);
    final inv = Invite.parse(text)!;
    expect((inv.stageId, inv.difficulty, inv.won, inv.baseHp), (w.stageId, w.difficulty, true, 14));
    expect(inv.isValidFor(app.pack), isTrue);
    // 保存は端末に残り、翌週は未挑戦に戻る
    final reloaded = await t.runAsync(AppState.load) as AppState;
    reloaded.today = () => '2026-10-23';
    expect(reloaded.weeklyRecord?.baseHp, 14); // 端末に保存されている
    app.today = () => '2026-10-26';
    expect(app.weeklyRecord, isNull);
    app.today = () => '2026-10-25'; // 同じ週の日曜はまだ挑戦済み
    expect(app.weeklyRecord, isNotNull);
    await t.pumpWidget(const SizedBox());
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

  testWidgets('招待: 州の長押しで招待をコピーでき、貼ると相手の結果が見えて、同じステージを遊べる。壊れた招待は遊べない', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await t.tap(find.byKey(const ValueKey('battle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('stage-view-toggle')));
    await t.pump();
    await t.longPress(find.byKey(const ValueKey('stage-US-CA')));
    await t.pump();
    expect(copied, contains('TMI1.${app.pack.packId}.normal.US-CA.normal'));
    expect(copied, contains('California'));
    await t.pump(const Duration(seconds: 3));
    final theirs = Invite(packId: app.pack.packId, kind: StageKind.normal, stageId: 'US-CA', difficulty: Difficulty.hard, won: true, baseHp: 12);
    await t.tap(find.byKey(const ValueKey('challenge')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const ValueKey('challenge-code')), 'Look!\n${app.inviteText(theirs)}\nPlay it');
    await t.pump();
    expect(find.textContaining('California'), findsWidgets);
    expect(find.textContaining('♥12'), findsWidgets);
    await t.enterText(find.byKey(const ValueKey('challenge-code')), 'TMI1.xx.normal.nowhere.hard');
    await t.pump();
    expect(find.text('This invite can\'t be used.'), findsOneWidget);
    expect((t.widget(find.byKey(const ValueKey('challenge-play'))) as FilledButton).onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('challenge-code')), theirs.toCode());
    await t.pump();
    await t.tap(find.byKey(const ValueKey('challenge-play')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('hud-wave')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('統計: ホームの右上から開ける。クイズ・バトル・連続日数・図鑑・実績の数字が、記録どおりに出る', (t) async {
    await t.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    app.today = () => '2026-10-19';
    final ids = [for (final r in app.pack.regions) r.id];
    await t.tap(find.byKey(const ValueKey('stats')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('stats-list')), findsOneWidget);
    expect(find.text('0 / ${ids.length}'), findsWidgets); // まだ何もしていない
    Navigator.of(t.element(find.byKey(const ValueKey('stats-list')))).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.runAsync(() async {
      await app.record(ids[0], correct: true);
      await app.record(ids[1], correct: false);
      await app.recordBattleClear(StageKind.normal, ids[0], Difficulty.easy);
      await app.recordBattleClear(StageKind.normal, ids[0], Difficulty.hard);
      await app.logBattle(won: true, seconds: 90);
      await app.logBattle(won: true, seconds: 30);
      await app.logBattle(won: false, seconds: 60);
      await app.logBattle(seconds: 3600); // 途中でやめた分の時間
    });
    final st = app.stats;
    expect((st.wins, st.losses, st.winRatePercent, st.playMinutes), (2, 1, 67, 63));
    expect((st.quizMastered, st.quizMissed), (1, 1));
    expect(st.statesCleared[Difficulty.easy], 1);
    expect(st.statesClearedAny, 1);
    await t.pumpWidget(MaterialApp(home: StatsScreen(app: app)));
    await t.pump();
    expect(find.byKey(const ValueKey('stats.mastered-value')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('stats.mastered-value'))).data, '1 / ${ids.length}');
    expect(t.widget<Text>(find.byKey(const ValueKey('stats.missed-value'))).data, '1');
    expect(t.widget<Text>(find.byKey(const ValueKey('stats.clearedEasy-value'))).data, '1 / ${ids.length}');
    expect(t.widget<Text>(find.byKey(const ValueKey('stats.clearedNormal-value'))).data, '0 / ${ids.length}');
    final statsScroll = find.descendant(of: find.byKey(const ValueKey('stats-list')), matching: find.byType(Scrollable));
    await t.scrollUntilVisible(find.byKey(const ValueKey('stats.streakBest-value')), 200, scrollable: statsScroll);
    expect(t.widget<Text>(find.byKey(const ValueKey('stats.streakBest-value'))).data, '0 days');
    await t.scrollUntilVisible(find.byKey(const ValueKey('stats.wins-value')), 200, scrollable: statsScroll);
    expect(t.widget<Text>(find.byKey(const ValueKey('stats.wins-value'))).data, '2');
    await t.scrollUntilVisible(find.byKey(const ValueKey('stats.playTime-value')), 200, scrollable: statsScroll);
    expect(t.widget<Text>(find.byKey(const ValueKey('stats.winRate-value'))).data, '67%');
    expect(t.widget<Text>(find.byKey(const ValueKey('stats.playTime-value'))).data, '1 h 3 min');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('復習: 間違えた州があるときだけ「復習」が出て、その州だけを出題する。正解すると減って、なくなると消える', (t) async {
    await t.binding.setSurfaceSize(const Size(480, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false);
    final id = freeRegionIds.first;
    expect(find.byKey(const ValueKey('review')), findsNothing); // まだ間違えていない
    await t.runAsync(() => app.record(id, correct: false));
    await t.pump();
    expect(find.byKey(const ValueKey('review')), findsOneWidget);
    expect(find.text('Review mistakes (1)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    final qs = t.widget<QuizScreen>(find.byType(QuizScreen)).questions;
    expect(qs, isNotEmpty);
    expect(qs.every((q) => q.targetId == id), isTrue); // 間違えた州だけ
    Navigator.of(t.element(find.byType(QuizScreen))).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    // 正解して習得済みになると、復習から外れて、ボタンが消える
    await t.runAsync(() => app.record(id, correct: true));
    await t.pump();
    expect(find.byKey(const ValueKey('review')), findsNothing);
    // 無料の間は、解放していない州の間違いは数えない
    final locked = app.pack.regions.map((r) => r.id).firstWhere((r) => !freeRegionIds.contains(r));
    await t.runAsync(() => app.record(locked, correct: false));
    await t.pump();
    expect(find.byKey(const ValueKey('review')), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('チュートリアル: 初回は案内が順に出て、スキップすると出ない。最初の波を終えると終わる。設定から、もう一度見られる', (t) async {
    await t.binding.setSurfaceSize(const Size(480, 1000)); // テストの文字は幅が広く、案内が何行にもなるので、少し大きめにする
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await boot(t, assist: false, tutorial: true);
    expect(app.tutorialDone, isFalse);
    await enterBattle(t, 'California');
    expect(find.byKey(const ValueKey('tutorial-placeSlot')), findsOneWidget);
    expect(find.text('Tap a build spot on the map to place a facility.'), findsOneWidget);

    final stage = StageGenerator(app.pack).generate('US-CA', Difficulty.normal);
    final slot = stage.slots.first;
    await tapCell(t, slot.col, slot.row, stage.cols, stage.rows);
    await t.pump();
    expect(find.byKey(const ValueKey('tutorial-placeFacility')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('place-farm')));
    await t.pump();
    expect(find.byKey(const ValueKey('tutorial-startWave')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('tutorial-skip')));
    await t.pump();
    expect(find.byKey(const ValueKey('tutorial-hint')), findsNothing);
    expect(app.tutorialDone, isTrue);
    expect((await t.runAsync(AppState.load) as AppState).tutorialDone, isTrue); // 端末に保存
    await app.setTutorialDone(false); // 設定の「もう一度見る」
    expect(app.tutorialDone, isFalse);
    await t.pumpWidget(const SizedBox());
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
    await t.tap(find.byKey(const ValueKey('stage-view-toggle')));
    await t.pump();
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

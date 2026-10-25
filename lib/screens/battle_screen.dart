import 'dart:async';

import 'package:app_common_kit/app_common_kit.dart' show showReviewPrePrompt;
import 'package:flutter/material.dart';
import 'boss_intro_card.dart';
import 'result_dialog.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:terrimap_core/battle/battle_engine.dart';
import 'package:terrimap_core/battle/invite.dart';
import 'package:terrimap_core/battle/replay.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/battle/stage.dart';
import 'package:terrimap_core/battle/stage_generator.dart';
import 'package:terrimap_core/battle/tutorial.dart';
import 'package:terrimap_core/battle/weekly_battle.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_core/battle_ui/battle_session.dart';
import 'package:terrimap_core/battle_ui/battle_view.dart';
import 'package:terrimap_core/story/story.dart';
import 'package:terrimap_core/i18n/ui_strings.dart';

import '../app_state.dart';
import '../sound.dart';
import 'assist_dialog.dart';
import 'replay_screen.dart';
import 'story_screen.dart';

/// バトル画面（最小版）。盤面、HUD、施設の設置・強化・撤去・修理、スキル選択（クイズ連動）、結果。
class BattleScreen extends StatefulWidget {
  final AppState app;
  final String regionId; // 種別に応じて 州・地方・エクストラ の id
  final Difficulty difficulty;
  final StageKind kind;
  final WeeklyBattle? weekly; // 今週のチャレンジのとき（1週に1回。やり直しはない）
  final bool endless; // エンドレス(州ひとつ・最大30波。クリア記録・物語・リプレイは対象外)
  const BattleScreen({super.key, required this.app, required this.regionId, required this.difficulty, this.kind = StageKind.normal, this.weekly, this.endless = false});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with SingleTickerProviderStateMixin {
  late final Stage _stage = widget.endless
      ? StageGenerator(widget.app.pack).endless(widget.regionId)
      : StageGenerator(widget.app.pack).generate(widget.regionId, widget.difficulty, kind: widget.kind);
  late final BattleSession _session = BattleSession(
    BattleEngine(_stage, profile: widget.app.pack.profile, pack: widget.app.pack, quizAssist: widget.app.quizAssist,
        reviewWeights: widget.weekly == null && !widget.endless ? widget.app.reviewWeights : null), // 毎週のチャレンジは全員同じ条件にする
  );
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _played = 0; // まだ記録していない、実際に遊んだ秒数
  BattleEvent? _lastEvent;
  String _message = '';
  String? _weather;
  ArtSet? _art; // 画像（読み込み前・画像なしは図形で描く）
  bool _bossIntroShown = false, _bossIntroVisible = false; // エクストラのボスが出たとき、名前と事実の注記を1回だけ出す
  Timer? _bossIntroTimer;
  bool _bossMusic = false; // ボスが出たら BGM をボス用にする（画面を出るとき元に戻す）
  List<String> _newCards = const []; // この勝利で集まった名所カード
  bool _resultShown = false;
  late bool _tutorial = !widget.app.tutorialDone; // 初回のバトルの案内（終えるかスキップするまで）
  Replay? _replay; // 終わったバトルの記録(今日のバトルの保存・共有に使う)
  bool _newEndlessBest = false; // エンドレスで、この結果が自己ベスト
  int _endlessWaves = 0; // エンドレスで守った波数
  List<StoryEpilogue> _newEpilogues = const []; // この結果で新しく読めるようになった続きの章

  /// このステージの物語の章（毎日・毎週のバトルでは出さない）。
  StoryChapter? get _chapter => widget.weekly != null || widget.endless ? null : widget.app.story?.forStage(widget.kind, widget.regionId);

  BattleEngine get _engine => _session.engine;
  UiStrings get _ui => widget.app.ui;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      if (!_session.paused && !_session.isOver) _played += dt;
      _session.tick(dt);
    })..start();
    _session.fx.enabled = widget.app.battleFx;
    _session.addListener(_onChanged);
    widget.app.art(bossId: _stage.extraId, stage: _stage).then((a) {
      if (mounted) setState(() => _art = a);
    });
    final ch = _chapter;
    if (ch != null && ch.intro.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showStoryLines(context, widget.app, title: ch.title.of(widget.app.lang), lines: ch.intro);
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_played > 0) widget.app.logBattle(seconds: _played); // 途中でやめた分の時間
    _bossIntroTimer?.cancel();
    if (_bossMusic) widget.app.bgmTrack('bgm');
    _session.removeListener(_onChanged);
    _session.dispose();
    super.dispose();
  }

  /// 組み合わせボーナスが初めて効いたとき、説明を1回だけ出す。
  void _maybeSynergyHint() {
    if (_engine.rules < 2 || widget.app.synergyHintSeen) return;
    final fs = _session.state.facilities;
    if (fs.values.any((f) => BattleEngine.neighborTypes(fs, f) > 0)) {
      widget.app.setSynergyHintSeen();
      _toast(_ui.t('synergy.hint'));
    }
  }

  void _onChanged() {
    // 新しいイベントを文言にする
    final log = _session.log;
    final idx = _lastEvent == null ? log.length : log.indexWhere((e) => identical(e, _lastEvent));
    final fresh = idx < 0 ? log : log.sublist(0, idx);
    if (fresh.isNotEmpty) {
      for (final e in fresh.reversed) {
        _handle(e);
      }
      _lastEvent = log.first;
    }
    if (mounted) setState(() {});
    _maybeSynergyHint();
    if (_tutorial && Tutorial.finished(_session.state, skillReady: _session.skillChoices.isNotEmpty)) {
      _tutorial = false;
      widget.app.setTutorialDone(true);
      _toast(_ui.t('tutorial.done'));
    }
    if (_session.isOver && !_resultShown) {
      _resultShown = true;
      widget.app.logBattle(won: _session.won, seconds: _played);
      widget.app.sfx(_session.won ? 'clear' : 'lose');
      _played = 0;
      if (widget.endless) {
        final cleared = _session.won ? _stage.waves.length : (_session.state.wave - 1).clamp(0, _stage.waves.length);
        widget.app.recordBattleDay();
        _endlessWaves = cleared;
        final before = widget.app.endlessBestWaves;
        widget.app.recordEndless(widget.regionId, cleared, _session.state.score).then((v) {
          _newEndlessBest = v; // 保存が済んでから結果を出す(自己ベストの表示に使う)
          _newEpilogues = widget.app.story?.newlyUnlocked(before, widget.app.endlessBestWaves) ?? const [];
          WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
        });
        return;
      }
      if (_session.won) {
        final before = widget.app.collection.unlockedIds;
        widget.app.recordBattleClear(widget.kind, widget.regionId, widget.difficulty); // 記録は同期で反映される
        widget.app.review?.recordPositiveMoment(); // 勝利は、レビューを頼んでよい「良い体験」
        _newCards = [for (final c in widget.app.collection.cards) if (c.unlocked && !before.contains(c.landmark.id)) c.landmark.nameIn(widget.app.lang)];
      }
      _replay = _session.recorder.toReplay(packId: widget.app.pack.packId, kind: widget.kind, stageId: widget.regionId, difficulty: widget.difficulty);
      widget.app.recordBattleDay();
      if (widget.weekly != null) widget.app.saveWeekly(widget.weekly!.week, _replay!.result.won, _replay!.result.baseHp);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  final SfxThrottle _sfxThrottle = SfxThrottle();

  /// 戦いの効果音(撃破・拠点被弾・ボス登場)。短い間に重ならないよう間引く。
  void _battleSfx(String name) {
    if (_sfxThrottle.allow(name, DateTime.now())) widget.app.sfx(name);
  }

  void _handle(BattleEvent e) {
    final ui = _ui;
    if (e.type == BattleEventType.breach) widget.app.haptic(heavy: e.isBoss);
    if (e.type == BattleEventType.kill && e.isBoss) widget.app.haptic(heavy: true);
    switch (e.type) {
      case BattleEventType.kill:
        _battleSfx(e.isBoss ? 'breach' : 'kill'); // ボスを倒したときは、重い音
      case BattleEventType.breach:
        _battleSfx('breach');
      case BattleEventType.spawn:
        if (e.isBoss) _battleSfx('boss_appear');
      default:
        break;
    }
    String weatherName() => ui.t('weather.${e.detail}');
    switch (e.type) {
      case BattleEventType.weatherWarning:
        _message = ui.t('weather.warning', {'name': weatherName()});
      case BattleEventType.weatherStart:
        _weather = e.detail;
        _message = ui.t('weather.start', {'name': weatherName()});
      case BattleEventType.weatherEnd:
        _weather = null;
        _message = ui.t('weather.end', {'name': weatherName()});
      case BattleEventType.weatherBlocked:
        _message = ui.t('weather.blocked', {'name': weatherName()});
      case BattleEventType.spawn:
        if (e.isBoss && !_bossMusic) {
          _bossMusic = true;
          widget.app.bgmTrack('boss');
        }
        if (e.isBoss && widget.kind == StageKind.extra && !_bossIntroShown) {
          _bossIntroShown = _bossIntroVisible = true;
          _bossIntroTimer = Timer(const Duration(seconds: 7), () {
            if (mounted) setState(() => _bossIntroVisible = false);
          });
        }
      case BattleEventType.bossSkill:
        _message = ui.t('boss.${e.detail}');
      case BattleEventType.facilityDestroyed:
        _message = ui.t('facility.destroyed');
      case BattleEventType.breach:
        _message = ui.t('base.breach');
      case BattleEventType.baseHeal:
        _message = ui.t('base.heal');
      default:
        break;
    }
  }

  String get _title {
    final app = widget.app, lang = app.lang, profile = app.pack.profile;
    switch (widget.kind) {
      case StageKind.normal:
        return app.s.regionName(widget.regionId);
      case StageKind.regional:
        return profile?.groups[widget.regionId]?.nameIn(lang) ?? widget.regionId;
      case StageKind.extra:
        final e = profile?.extras.where((x) => x.id == widget.regionId).firstOrNull;
        return e == null ? widget.regionId : (e.title[lang] ?? e.title['en'] ?? e.id);
    }
  }

  String _facilityName(FacilityType t) {
    final skin = widget.app.pack.profile?.facilitySkins[t.name];
    return skin?.name[widget.app.lang] ?? _ui.t('facility.${t.name}');
  }

  /// 限定施設の名前。文言(exclusive.name.<id>)があればそれ、なければ id から組み立てる。
  String _exclusiveName(String id) => _ui.has('exclusive.name.$id')
      ? _ui.t('exclusive.name.$id')
      : id.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  // ── 操作 ──

  Future<void> _skillFlow() async {
    final ui = _ui;
    if (_session.skillNeedsQuiz) {
      final q = _session.skillQuestion;
      if (q != null) {
        _session.paused = true;
        final ok = await showAssistQuestion(context, widget.app, q, title: ui.t('assist.skillTitle'), timeLimit: _engine.assistTimeLimit);
        _session.paused = false;
        widget.app.record(q.targetId, correct: ok);
        _session.answerSkillQuiz(correct: ok);
        if (!ok) {
          if (mounted) _toast(ui.t('assist.skillWrong', {'name': ui.t('skill.${_session.state.skill}')}));
          return;
        }
        _toast(ui.t('assist.skillRight'));
      }
    }
    if (!mounted) return;
    final choices = _session.skillChoices;
    if (choices.isEmpty) return;
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ui.t('skill.choose')),
        children: [
          for (final id in choices)
            SimpleDialogOption(
              key: ValueKey('skill-$id'),
              onPressed: () => Navigator.pop(ctx, id),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ui.t('skill.$id'), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(ui.t('skill.$id.desc'), style: Theme.of(ctx).textTheme.bodySmall),
              ]),
            ),
        ],
      ),
    );
    if (pick != null) _session.chooseSkill(pick);
  }

  Future<void> _repairFlow() async {
    final sel = _session.selected;
    final f = _session.selectedFacility;
    if (sel == null || f == null) return;
    final ui = _ui;
    if (_engine.assistEnabled) {
      final q = _session.repairQuestion(sel);
      if (q != null) {
        _session.paused = true;
        final ok = await showAssistQuestion(context, widget.app, q, title: ui.t('assist.repairTitle'), timeLimit: _engine.assistTimeLimit);
        _session.paused = false;
        widget.app.record(q.targetId, correct: ok);
        final cost = _engine.repairCostOf(f);
        if (_session.repair(correct: ok)) {
          if (mounted) _toast(ok ? ui.t('assist.repairRight') : ui.t('assist.repairWrong', {'n': cost ?? 0}));
        }
        return;
      }
    }
    _session.repair();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(label);
  }

  Future<void> _showResult() async {
    if (!mounted) return;
    final ch = _chapter;
    if (_session.won && ch != null && ch.outro.isNotEmpty) {
      await showStoryLines(context, widget.app, title: ch.title.of(widget.app.lang), lines: ch.outro);
      if (!mounted) return;
    }
    for (final e in _newEpilogues) {
      await showStoryLines(context, widget.app, title: e.title.of(widget.app.lang), lines: e.lines);
      if (!mounted) return;
    }
    final ui = _ui;
    final st = _session.state;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ResultDialog(
        won: _session.won,
        title: _session.won ? ui.t('result.victory') : ui.t('result.defeat'),
        stars: resultStars(won: _session.won, baseHp: st.baseHp, maxHp: _stage.baseHp),
        score: st.score,
        scoreText: (n) => ui.t('result.score', {'n': n}),
        subtitle: ui.t('result.waves', {'n': _session.won ? _stage.waves.length : (st.wave - 1).clamp(0, 99)}),
        backdrop: _art?.backdrop(_stage.backdrop),
        extra: [
          if (widget.endless && _newEndlessBest) widget.app.s.t('endless.newBest'),
          if (_newCards.isNotEmpty) '${ui.t('collection.new')}\n${_newCards.map((n) => '• $n').join('\n')}',
        ].join('\n\n'),
        secondary: [
          if (widget.endless)
            TextButton(
              key: const ValueKey('share-endless'),
              onPressed: () => _copy(widget.app.endlessShareText(widget.regionId, _endlessWaves, st.score), ui.t('invite.copied')),
              child: Text(widget.app.s.t('endless.share')),
            ),
          if (_replay != null)
            TextButton(
              key: const ValueKey('watch-replay'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReplayScreen(app: widget.app, replay: _replay!))),
              child: Text(ui.t('replay.watch')),
            ),
          if (_replay != null)
            TextButton(
              key: const ValueKey('share-challenge'),
              onPressed: () => _copy(_replay!.toShareCode(), ui.t('daily.challenge')),
              child: Text(ui.t('invite.replayCode')),
            ),
          if (_replay != null)
            TextButton(
              key: const ValueKey('share-invite'),
              onPressed: () => _copy(widget.app.inviteText(Invite.fromReplay(_replay!)), ui.t('invite.copied')),
              child: Text(ui.t('invite.title')),
            ),
        ],
        primary: [
          if (widget.weekly == null) // 今週のチャレンジは1回きり
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => BattleScreen(app: widget.app, regionId: widget.regionId, difficulty: widget.difficulty, kind: widget.kind, endless: widget.endless),
              ));
            },
            child: Text(ui.t('result.retry')),
          ),
          OutlinedButton(
            onPressed: () {
              final nav = Navigator.of(context);
              final review = widget.app.review;
              final ask = _session.won && review != null;
              nav.pop(); // 結果
              nav.pop(); // バトル画面
              // 勝って戻ったあとに、条件を満たしていれば「楽しんでいますか？」を出す（負けた直後・戦闘中には出さない）
              if (ask) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (nav.mounted) showReviewPrePrompt(nav.context, review, strings: widget.app.s.kit);
                });
              }
            },
            child: Text(ui.t('result.back')),
          ),
        ],
      ),
    );
  }

  // ── 画面 ──

  @override
  Widget build(BuildContext context) {
    final ui = _ui, st = _session.state;
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final board = Stack(children: [
              Padding(
              padding: const EdgeInsets.all(8),
              child: BattleView(
                key: const ValueKey('board'),
                stage: _stage,
                state: st,
                selected: _session.selected,
                selectedRange: _session.selectedFacility == null ? null : _engine.facilityStats(_session.selectedFacility!).range,
                facilityMaxHp: _engine.maxHpOf,
                art: _art,
                weather: _weather,
                fx: _session.fx,
                synergy: _engine.rules >= 2,
                onCellTap: _session.tapCell,
              ),
              ),
              if (_bossIntroVisible) Positioned(top: 8, left: 8, right: 8, child: _bossIntro()),
            ]);
    return Scaffold(
      appBar: AppBar(
        title: Text('$_title · ${ui.t('difficulty.${widget.difficulty.name}')}', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const ValueKey('speed'),
            tooltip: ui.t('hud.speed', {'n': _session.speed == 1 ? 2 : 1}),
            icon: Text('×${_session.speed.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _session.setSpeed(_session.speed == 1 ? 2 : 1),
          ),
          IconButton(
            key: const ValueKey('pause'),
            tooltip: _session.paused ? ui.t('hud.resume') : ui.t('hud.pause'),
            icon: Icon(_session.paused ? Icons.play_arrow : Icons.pause),
            onPressed: _session.togglePause,
          ),
        ],
      ),
      body: SafeArea(
        child: landscape
            ? Row(children: [
                Expanded(child: board),
                SizedBox(
                  width: 340,
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _hud(st),
                      if (_message.isNotEmpty)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text(_message, style: Theme.of(context).textTheme.bodySmall)),
                      if (_tutorial) _tutorialHint(st),
                      _panel(st, side: true),
                    ]),
                  ),
                ),
              ])
            : Column(children: [
          // HUD・メッセージ・下のパネルは高さを固定する。出入りで盤面が動いたり拡縮したりすると、
          // 指で押した位置とずれて誤タップするため。
          SizedBox(height: 92, child: ClipRect(child: _hud(st))),
          SizedBox(
            height: 22,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_message, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          if (_tutorial) _tutorialHint(st),
          Expanded(child: board),
          _panel(st),
        ]),
      ),
    );
  }

  /// 初回のバトルの案内。画面を止めず、いまやることを短く出す。
  /// チュートリアルの案内は、ステップごとに文の長さが変わっても盤面が動かないよう高さを固定する。
  static const double _tutorialHeight = 124;

  Widget _tutorialHint(BattleState st) {
    final step = Tutorial.stepFor(st, selecting: _session.selected != null && _session.selectedFacility == null, skillReady: _session.skillChoices.isNotEmpty);
    if (step == null) return const SizedBox(height: _tutorialHeight);
    final ui = _ui;
    return SizedBox(
      height: _tutorialHeight,
      child: Card(
      key: const ValueKey('tutorial-hint'),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(children: [
          const Icon(Icons.lightbulb_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(ui.t('tutorial.${step.name}'), key: ValueKey('tutorial-${step.name}'))),
          TextButton(
            key: const ValueKey('tutorial-skip'),
            onPressed: () {
              widget.app.setTutorialDone(true);
              setState(() => _tutorial = false);
            },
            child: Text(ui.t('tutorial.skip')),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _bossIntro() {
    final app = widget.app, ui = _ui;
    final extra = app.pack.profile?.extras.where((x) => x.id == widget.regionId).firstOrNull;
    if (extra == null) return const SizedBox.shrink();
    return BossIntroCard(
      title: ui.t('stage.boss', {'name': extra.bossNameIn(app.lang)}),
      basisLabel: ui.t('stage.basis.${extra.basis}'),
      fact: extra.factIn(app.lang),
      onClose: () => setState(() => _bossIntroVisible = false),
    );
  }

  Widget _hud(BattleState st) {
    final ui = _ui;
    final wave = st.wave.clamp(0, _stage.waves.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(ui.t('hud.wave', {'n': wave, 'total': _stage.waves.length}), key: const ValueKey('hud-wave')),
        Text('♥ ${st.baseHp}/${_stage.baseHp}', key: const ValueKey('hud-base')),
        Text('● ${st.coins}', key: const ValueKey('hud-coins')),
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text(ui.t('season.${_stage.seasonAt(st.phase == BattlePhase.wave ? st.wave : st.wave + 1).name}')),
        ),
        if (_weather != null)
          Chip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.cloud, size: 16), label: Text(ui.t('weather.$_weather'))),
        if (BattleEngine.quizBuffBonus(st) > 0)
          Chip(
            key: const ValueKey('hud-buff'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.bolt, size: 16),
            label: Text('+${(BattleEngine.quizBuffBonus(st) * 100).round()}%  ${(st.buffUntil - st.time).ceil()}s'),
          ),
        if (st.skill != null)
          Chip(visualDensity: VisualDensity.compact, label: Text(ui.t('skill.active', {'name': ui.t('skill.${st.skill}')}))),
        if (_session.inPrep && st.wave < _stage.waves.length)
          Text(ui.t('hud.prepare', {'s': st.prepTimer.ceil()}), style: const TextStyle(fontStyle: FontStyle.italic)),
      ]),
    );
  }

  /// 施設の一覧やボタンの並び。横向き(右の列)は折り返し、縦向きは横スクロールの1行にして、下のパネルを低くする。
  Widget _strip(bool side, List<Widget> items) {
    if (side) return Wrap(spacing: 6, runSpacing: 6, children: items);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [for (final w in items) Padding(padding: const EdgeInsets.only(right: 8), child: w)],
      ),
    );
  }

  Widget _panel(BattleState st, {bool side = false}) {
    final ui = _ui;
    final sel = _session.selected, f = _session.selectedFacility;
    final children = <Widget>[];
    if (_session.inPrep && st.wave < _stage.waves.length) {
      children.add(_strip(side, [
        FilledButton(key: const ValueKey('start-wave'), onPressed: _session.startWave, child: Text(ui.t('hud.startWave'))),
        if (_session.skillChoices.isNotEmpty)
          OutlinedButton.icon(
            key: const ValueKey('skill'),
            icon: const Icon(Icons.auto_awesome, size: 18),
            onPressed: _skillFlow,
            label: Text(ui.t('skill.choose')),
          ),
      ]));
    }
    if (sel != null && f == null) {
      children.add(_strip(side, [
        for (final t in FacilityType.values)
          Tooltip(
            message: ui.t('facility.${t.name}.desc'),
            child: FilledButton.tonal(
              key: ValueKey('place-${t.name}'),
              onPressed: st.coins >= _engine.costOf(t) ? () => _session.place(t) : null,
              child: Text('${_facilityName(t)} ${_engine.costOf(t)}'),
            ),
          ),
        if (_engine.exclusiveLeft(st).isNotEmpty && _engine.exclusiveCostOf(_engine.exclusiveLeft(st).first) != null)
          FilledButton(
            key: const ValueKey('place-exclusive'),
            onPressed: st.coins >= _engine.exclusiveCostOf(_engine.exclusiveLeft(st).first)! ? _session.placeExclusive : null,
            child: Text('★ ${_exclusiveName(_engine.exclusiveLeft(st).first)} ${_engine.exclusiveCostOf(_engine.exclusiveLeft(st).first)}'),
          ),
      ]));
    } else if (f != null) {
      final up = _engine.upgradeCostOf(f), rep = _engine.repairCostOf(f), max = _engine.maxHpOf(f);
      final name = f.exclusive != null ? '★ ${_exclusiveName(f.exclusive!)}' : _facilityName(f.type);
      children.add(Text('$name · ${ui.t('facility.level', {'n': f.level})}${max > 0 ? ' · HP ${f.hp}/$max' : ''}'));
      children.add(_strip(side, [
        if (f.exclusive == null)
          FilledButton.tonal(
            key: const ValueKey('upgrade'),
            onPressed: up != null && st.coins >= up ? _session.upgrade : null,
            child: Text(up == null ? ui.t('facility.maxLevel') : ui.t('facility.upgrade', {'n': up})),
          ),
        if (rep != null)
          FilledButton.tonal(
            key: const ValueKey('repair'),
            onPressed: _engine.assistEnabled || st.coins >= rep ? _repairFlow : null,
            child: Text(_engine.assistEnabled ? ui.t('facility.repairFree') : ui.t('facility.repair', {'n': rep})),
          ),
        OutlinedButton(
          key: const ValueKey('remove'),
          onPressed: _session.remove,
          child: Text(ui.t('facility.remove', {'n': (f.invested * BattleEngine.refundRatio).round()})),
        ),
      ]));
    }
    if (side) {
      // 横向き: 右の列の中に自然な高さで並べる(列ごとスクロールできる。盤面は動かない)
      if (children.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 6), child: c),
        ]),
      );
    }
    // 縦向き: 下のパネルは1〜2行の横並びに低く抑える(盤面を大きくするため)。高さは固定して盤面が動かないようにする。
    const panelHeight = 132.0;
    if (children.isEmpty) return const SizedBox(height: panelHeight);
    return SizedBox(
      height: panelHeight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 6), child: c),
        ]),
      ),
    );
  }
}

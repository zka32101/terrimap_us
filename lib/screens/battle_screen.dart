import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:terrimap_core/battle/battle_engine.dart';
import 'package:terrimap_core/battle/daily_battle.dart';
import 'package:terrimap_core/battle/replay.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/battle/stage.dart';
import 'package:terrimap_core/battle/stage_generator.dart';
import 'package:terrimap_core/battle_ui/battle_session.dart';
import 'package:terrimap_core/battle_ui/battle_view.dart';
import 'package:terrimap_core/i18n/ui_strings.dart';

import '../app_state.dart';
import 'assist_dialog.dart';
import 'replay_screen.dart';

/// バトル画面（最小版）。盤面、HUD、施設の設置・強化・撤去・修理、スキル選択（クイズ連動）、結果。
class BattleScreen extends StatefulWidget {
  final AppState app;
  final String regionId; // 種別に応じて 州・地方・エクストラ の id
  final Difficulty difficulty;
  final StageKind kind;
  final DailyBattle? daily; // 今日のバトルのとき
  const BattleScreen({super.key, required this.app, required this.regionId, required this.difficulty, this.kind = StageKind.normal, this.daily});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with SingleTickerProviderStateMixin {
  late final Stage _stage = StageGenerator(widget.app.pack).generate(widget.regionId, widget.difficulty, kind: widget.kind);
  late final BattleSession _session = BattleSession(
    BattleEngine(_stage, profile: widget.app.pack.profile, pack: widget.app.pack, quizAssist: widget.app.quizAssist,
        reviewWeights: widget.daily == null ? widget.app.reviewWeights : null), // 毎日のバトルは全員同じ条件にする
  );
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  BattleEvent? _lastEvent;
  String _message = '';
  String? _weather;
  List<String> _newCards = const []; // この勝利で集まった名所カード
  bool _resultShown = false;
  Replay? _replay; // 終わったバトルの記録(今日のバトルの保存・共有に使う)

  BattleEngine get _engine => _session.engine;
  UiStrings get _ui => widget.app.ui;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      _session.tick(dt);
    })..start();
    _session.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _session.removeListener(_onChanged);
    _session.dispose();
    super.dispose();
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
    if (_session.isOver && !_resultShown) {
      _resultShown = true;
      if (_session.won) {
        final before = widget.app.collection.unlockedIds;
        widget.app.recordBattleClear(widget.kind, widget.regionId, widget.difficulty); // 記録は同期で反映される
        _newCards = [for (final c in widget.app.collection.cards) if (c.unlocked && !before.contains(c.landmark.id)) c.landmark.nameIn(widget.app.lang)];
      }
      _replay = _session.recorder.toReplay(packId: widget.app.pack.packId, kind: widget.kind, stageId: widget.regionId, difficulty: widget.difficulty);
      if (widget.daily != null) widget.app.saveDaily(widget.daily!.date, _replay!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  void _handle(BattleEvent e) {
    final ui = _ui;
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

  void _showResult() {
    if (!mounted) return;
    final ui = _ui;
    final st = _session.state;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(_session.won ? ui.t('result.victory') : ui.t('result.defeat')),
        content: Text('${ui.t('result.waves', {'n': _session.won ? _stage.waves.length : (st.wave - 1).clamp(0, 99)})}\n${ui.t('result.score', {'n': st.score})}'
            '${_newCards.isEmpty ? '' : '\n\n${ui.t('collection.new')}\n${_newCards.map((n) => '• $n').join('\n')}'}'),
        actions: [
          if (widget.daily != null && _replay != null)
            TextButton(
              key: const ValueKey('share-daily'),
              onPressed: () => _copy(widget.daily!.shareText(widget.app.s.t('appTitle'), _replay!.result, totalWaves: _stage.waves.length, maxBaseHp: _stage.baseHp), ui.t('daily.share')),
              child: Text(ui.t('daily.share')),
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
              child: Text(ui.t('daily.challenge')),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => BattleScreen(app: widget.app, regionId: widget.regionId, difficulty: widget.difficulty, kind: widget.kind, daily: widget.daily),
              ));
            },
            child: Text(ui.t('result.retry')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
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
        child: Column(children: [
          _hud(st),
          if (_message.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(_message, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: BattleView(
                key: const ValueKey('board'),
                stage: _stage,
                state: st,
                selected: _session.selected,
                selectedRange: _session.selectedFacility == null ? null : _engine.facilityStats(_session.selectedFacility!).range,
                facilityMaxHp: _engine.maxHpOf,
                weather: _weather,
                onCellTap: _session.tapCell,
              ),
            ),
          ),
          _panel(st),
        ]),
      ),
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

  Widget _panel(BattleState st) {
    final ui = _ui;
    final sel = _session.selected, f = _session.selectedFacility;
    final children = <Widget>[];
    if (_session.inPrep && st.wave < _stage.waves.length) {
      children.add(Wrap(spacing: 8, runSpacing: 6, children: [
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
      children.add(Wrap(spacing: 6, runSpacing: 6, children: [
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
      children.add(Wrap(spacing: 6, runSpacing: 6, children: [
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
    if (children.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 6), child: c),
      ]),
    );
  }
}

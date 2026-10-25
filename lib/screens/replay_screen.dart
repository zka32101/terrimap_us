import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:terrimap_core/battle/battle_engine.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/battle/replay.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_core/battle_ui/battle_view.dart';
import 'package:terrimap_core/battle_ui/replay_player.dart';
import 'package:terrimap_core/i18n/ui_strings.dart';

import '../app_state.dart';

/// リプレイの視聴画面。記録された操作を、遊んだときと同じ結果で再生する。
class ReplayScreen extends StatefulWidget {
  final AppState app;
  final Replay replay;
  const ReplayScreen({super.key, required this.app, required this.replay});
  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> with SingleTickerProviderStateMixin {
  late final ReplayPlayer _player = ReplayPlayer(widget.replay.buildEngine(widget.app.pack), widget.replay);
  late final Ticker _ticker;
  ArtSet? _art; // 画像（読み込み前・画像なしは図形で描く）
  Duration _last = Duration.zero;

  UiStrings get _ui => widget.app.ui;
  BattleEngine get _engine => _player.engine;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      _player.tick(dt);
    })..start();
    _player.fx.enabled = widget.app.battleFx;
    _player.addListener(_onChanged);
    widget.app.art(bossId: _engine.stage.extraId, stage: _engine.stage).then((a) {
      if (mounted) setState(() => _art = a);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _player.removeListener(_onChanged);
    _player.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ui = _ui, st = _player.state, stage = _engine.stage;
    final r = widget.replay;
    final title = r.kind == StageKind.normal ? widget.app.s.regionName(r.stageId) : r.stageId;
    final wave = st.wave.clamp(0, stage.waves.length);
    return Scaffold(
      appBar: AppBar(title: Text('${ui.t('replay.title')} · $title · ${ui.t('difficulty.${r.difficulty.name}')}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(ui.t('hud.wave', {'n': wave, 'total': stage.waves.length}), key: const ValueKey('replay-wave')),
              Text('♥ ${st.baseHp}/${stage.baseHp}', key: const ValueKey('replay-base')),
              Text('● ${st.coins}'),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 0), child: LinearProgressIndicator(value: _player.progress)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: BattleView(key: const ValueKey('replay-board'), stage: stage, state: st, facilityMaxHp: _engine.maxHpOf, art: _art, fx: _player.fx, synergy: _engine.rules >= 2),
            ),
          ),
          if (_player.corrupt)
            Padding(padding: const EdgeInsets.all(8), child: Text(ui.t('replay.invalid'), key: const ValueKey('replay-invalid')))
          else if (_player.isOver)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${ui.t('replay.finished')} · ${_player.won ? ui.t('result.victory') : ui.t('result.defeat')}${_player.matchesRecorded ? '\n${ui.t('replay.matches')}' : ''}',
                key: const ValueKey('replay-done'),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              IconButton.filledTonal(
                key: const ValueKey('replay-pause'),
                tooltip: _player.paused ? ui.t('hud.resume') : ui.t('hud.pause'),
                icon: Icon(_player.paused ? Icons.play_arrow : Icons.pause),
                onPressed: _player.finished ? null : _player.togglePause,
              ),
              for (final s in const [1.0, 2.0, 4.0])
                ChoiceChip(
                  key: ValueKey('replay-speed-${s.toInt()}'),
                  label: Text('×${s.toInt()}'),
                  selected: _player.speed == s,
                  onSelected: (_) => _player.setSpeed(s),
                ),
              OutlinedButton(key: const ValueKey('replay-restart'), onPressed: _player.restart, child: Text(ui.t('replay.restart'))),
              OutlinedButton(key: const ValueKey('replay-skip'), onPressed: _player.finished ? null : _player.skipToEnd, child: Text(ui.t('replay.skip'))),
            ]),
          ),
        ]),
      ),
    );
  }
}

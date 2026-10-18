import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/pack/country_profile.dart';

import '../app_state.dart';
import '../monetization.dart';
import 'battle_screen.dart';
import 'unlock_sheet.dart';

/// 守るステージ（州／地方決戦／エクストラ）と難易度を選ぶ画面。
/// 州は無料枠以外が買い切り。地方決戦とエクストラは買い切り＋クリア記録での解放。
class StagePickerScreen extends ConsumerStatefulWidget {
  final AppState app;
  const StagePickerScreen({super.key, required this.app});
  @override
  ConsumerState<StagePickerScreen> createState() => _StagePickerState();
}

class _StagePickerState extends ConsumerState<StagePickerScreen> {
  Difficulty _difficulty = Difficulty.normal;
  StageKind _kind = StageKind.normal;

  void _play(StageKind kind, String id) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BattleScreen(app: widget.app, regionId: id, difficulty: _difficulty, kind: kind),
      ));

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final s = app.s, ui = app.ui;
    final service = ref.watch(entitlementServiceProvider);
    final premium = ref.watch(entitlementStateProvider).valueOrNull?.hasPremium ?? service.state.hasPremium;
    final profile = app.pack.profile;
    final hasRegional = profile?.groups.isNotEmpty ?? false;
    final hasExtra = profile?.extras.isNotEmpty ?? false;
    final modes = [StageKind.normal, if (hasRegional) StageKind.regional, if (hasExtra) StageKind.extra];
    return Scaffold(
      appBar: AppBar(title: Text(s.t('battle'))),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<Difficulty>(
              segments: [for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(ui.t('difficulty.${d.name}')))],
              selected: {_difficulty},
              onSelectionChanged: (v) => setState(() => _difficulty = v.first),
            ),
          ),
          if (modes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<StageKind>(
                key: const ValueKey('modes'),
                segments: [
                  for (final k in modes)
                    ButtonSegment(value: k, label: Text(ui.t(const {StageKind.normal: 'stage.mode.state', StageKind.regional: 'stage.mode.region', StageKind.extra: 'stage.mode.extra'}[k]!))),
                ],
                selected: {_kind},
                onSelectionChanged: (v) => setState(() => _kind = v.first),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _kind == StageKind.normal
                  ? ui.t('stage.choose')
                  : ui.t('stage.progress', {'n': app.battle.clearedStates([for (final r in app.pack.regions) r.id]), 'total': app.pack.regions.length}),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(child: ListView(children: switch (_kind) {
            StageKind.normal => _states(premium),
            StageKind.regional => _regions(premium),
            StageKind.extra => _extras(premium),
          })),
        ]),
      ),
    );
  }

  List<Widget> _states(bool premium) {
    final app = widget.app, s = app.s, ui = app.ui;
    final ids = [for (final r in app.pack.regions) r.id]..sort((a, b) => s.regionName(a).compareTo(s.regionName(b)));
    return [
      for (final id in ids)
        ListTile(
          key: ValueKey('stage-$id'),
          title: Text(s.regionName(id)),
          subtitle: Text(ui.t('stage.base', {'capital': s.capitalName(id)})),
          trailing: !isRegionUnlocked(id, premium: premium)
              ? const Icon(Icons.lock_outline)
              : app.battle.isCleared(StageKind.normal, id)
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.chevron_right),
          onTap: () {
            if (!isRegionUnlocked(id, premium: premium)) {
              showUnlockSheet(context, app);
              return;
            }
            _play(StageKind.normal, id);
          },
        ),
    ];
  }

  List<Widget> _regions(bool premium) {
    final app = widget.app, ui = app.ui, lang = app.lang;
    return [
      for (final g in app.pack.profile!.groups.values)
        _lockTile(
          key: 'region-${g.id}',
          title: g.nameIn(lang),
          subtitle: '${ui.t('stage.progress', {'n': app.battle.regionalProgress(g), 'total': g.regions.length})} · ${ui.t('stage.regionBase', {'capital': app.s.capitalName(g.center)})}',
          cleared: app.battle.isCleared(StageKind.regional, g.id),
          lockedReason: !premium ? 'stage.locked.premium' : !app.battle.regionalUnlocked(g) ? 'stage.locked.region' : null,
          onPlay: () => _play(StageKind.regional, g.id),
        ),
    ];
  }

  List<Widget> _extras(bool premium) {
    final app = widget.app, ui = app.ui, lang = app.lang;
    final unlocked = app.battle.extraUnlocked(app.pack);
    String tr(Map<String, String> m) => m[lang] ?? m['en'] ?? '';
    return [
      for (final e in app.pack.profile!.extras)
        _lockTile(
          key: 'extra-${e.id}',
          title: tr(e.title),
          subtitle: '${ui.t('stage.basis.${e.basis}')} · ${ui.t('stage.waves', {'n': e.waves})}',
          cleared: app.battle.isCleared(StageKind.extra, e.id),
          lockedReason: !premium ? 'stage.locked.premium' : !unlocked ? 'stage.locked.extra' : null,
          onPlay: () => _extraInfo(e),
        ),
    ];
  }

  Widget _lockTile({required String key, required String title, required String subtitle, required bool cleared, required String? lockedReason, required VoidCallback onPlay}) {
    final app = widget.app;
    return ListTile(
      key: ValueKey(key),
      title: Text(title),
      subtitle: Text(lockedReason == null ? subtitle : app.ui.t(lockedReason)),
      trailing: lockedReason != null
          ? const Icon(Icons.lock_outline)
          : cleared
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.chevron_right),
      onTap: () {
        if (lockedReason == 'stage.locked.premium') {
          showUnlockSheet(context, app);
        } else if (lockedReason != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.ui.t(lockedReason))));
        } else {
          onPlay();
        }
      },
    );
  }

  /// エクストラの題材・事実の注記・ボスを見せてから始める。
  void _extraInfo(ExtraStage e) {
    final app = widget.app, ui = app.ui, lang = app.lang;
    String tr(Map<String, String> m) => m[lang] ?? m['en'] ?? '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(tr(e.title), style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(ui.t('stage.basis.${e.basis}'), style: Theme.of(ctx).textTheme.labelMedium),
            const SizedBox(height: 12),
            Text(ui.t('stage.about'), style: Theme.of(ctx).textTheme.titleSmall),
            Text(tr(e.summary)),
            const SizedBox(height: 12),
            Text(ui.t('stage.fact'), style: Theme.of(ctx).textTheme.titleSmall),
            Text(tr(e.fact), key: const ValueKey('extra-fact')),
            const SizedBox(height: 12),
            Text(ui.t('stage.boss', {'name': tr(e.bossName)})),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('extra-play'),
              onPressed: () {
                Navigator.pop(ctx);
                _play(StageKind.extra, e.id);
              },
              child: Text(ui.t('stage.play')),
            ),
          ]),
        ),
      ),
    );
  }
}

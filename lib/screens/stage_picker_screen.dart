import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'achievements_screen.dart';
import 'collection_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terrimap_core/battle/daily_battle.dart';
import 'package:terrimap_core/battle/invite.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/replay.dart';
import 'package:terrimap_core/battle/weekly_battle.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/pack/country_profile.dart';

import '../app_state.dart';
import '../monetization.dart';
import 'battle_screen.dart';
import 'replay_screen.dart';
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

  void _play(StageKind kind, String id, {Difficulty? difficulty, DailyBattle? daily, WeeklyBattle? weekly}) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BattleScreen(app: widget.app, regionId: id, difficulty: difficulty ?? _difficulty, kind: kind, daily: daily, weekly: weekly),
      ));

  void _watch(Replay r) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReplayScreen(app: widget.app, replay: r)));

  /// 今日のバトル。無料の間は、無料の州だけから選ぶ。
  DailyBattle _daily(bool premium) =>
      DailyBattle.forDate(widget.app.pack, widget.app.today(), allowedIds: premium ? null : freeRegionIds);

  Widget _dailyCard(bool premium) {
    final app = widget.app, ui = app.ui;
    final d = _daily(premium);
    final done = app.dailyReplay(d.date);
    final streak = app.streak.currentOn(app.today());
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        key: const ValueKey('daily-battle'),
        leading: const Icon(Icons.today),
        title: Text(ui.t('daily.title')),
        subtitle: Text([
          done != null
              ? '${ui.t('daily.done')}  ${done.result.won ? '✅' : '❌'} ♥${done.result.baseHp}'
              : ui.t('daily.today', {'name': app.s.regionName(d.stageId), 'difficulty': ui.t('difficulty.${d.difficulty.name}')}),
          if (streak > 0) '🔥 $streak',
        ].join('  ')),
        trailing: done != null ? const Icon(Icons.play_circle_outline, key: ValueKey('daily-watch')) : const Icon(Icons.chevron_right),
        onTap: done != null ? () => _watch(done) : () => _play(d.kind, d.stageId, difficulty: d.difficulty, daily: d),
      ),
    );
  }

  /// 今週のチャレンジ。1週に1回だけ。終えたら結果と、友だちへの共有を出す。
  Widget _weeklyCard(bool premium) {
    final app = widget.app, ui = app.ui;
    final w = app.weekly(premium: premium, freeIds: freeRegionIds);
    final rec = app.weeklyRecord;
    final left = WeeklyBattle.daysLeft(app.today());
    final stage = w.kind == StageKind.regional ? app.pack.profile?.groups[w.stageId]?.nameIn(app.lang) ?? w.stageId : app.s.regionName(w.stageId);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        key: const ValueKey('weekly-battle'),
        leading: const Icon(Icons.event_available),
        title: Text(ui.t('weekly.title')),
        isThreeLine: true,
        subtitle: Text([
          if (rec != null) ui.t('weekly.done', {'mark': rec.won ? '✅' : '❌', 'hp': rec.baseHp}) else '$stage · ${ui.t('difficulty.${w.difficulty.name}')}',
          rec != null ? ui.t('weekly.doneHint') : ui.t('weekly.once'),
          left == 1 ? ui.t('weekly.lastDay') : ui.t('weekly.daysLeft', {'n': left}),
        ].join('\n')),
        trailing: rec != null ? IconButton(key: const ValueKey('weekly-share'), tooltip: ui.t('weekly.share'), icon: const Icon(Icons.ios_share), onPressed: () => _copyWeekly(w, rec)) : const Icon(Icons.chevron_right),
        onTap: rec != null ? null : () => _play(w.kind, w.stageId, difficulty: w.difficulty, weekly: w),
      ),
    );
  }

  void _copyWeekly(WeeklyBattle w, WeeklyRecord rec) {
    Clipboard.setData(ClipboardData(text: widget.app.weeklyText(w, record: rec)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.app.ui.t('invite.copied'))));
  }

  /// 友だちの挑戦コードを貼って確かめ、同じステージで挑戦する。
  Future<void> _challengeDialog() async {
    final app = widget.app, ui = app.ui;
    final ctl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final r = Replay.fromShareCode(ctl.text.trim());
        final ok = r != null && r.packId == app.pack.packId && r.verify(app.pack);
        final inv = Invite.parse(ctl.text);
        final invOk = inv != null && inv.isValidFor(app.pack);
        final premium = ref.read(entitlementServiceProvider).state.hasPremium;
        // 招待のステージを、今の解放の条件で遊べるか
        final invPlayable = invOk &&
            switch (inv.kind) {
              StageKind.normal => isRegionUnlocked(inv.stageId, premium: premium),
              StageKind.regional => premium && app.battle.regionalUnlocked(app.pack.profile!.groups[inv.stageId]!),
              StageKind.extra => premium && app.battle.extraUnlocked(app.pack),
            };
        return AlertDialog(
          title: Text(ui.t('daily.challenge')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ui.t('invite.hint')),
            TextField(
              key: const ValueKey('challenge-code'),
              controller: ctl,
              onChanged: (_) => setS(() {}),
              maxLines: 2,
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  key: const ValueKey('challenge-paste'),
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
                    ctl.text = clip.trim();
                    setS(() {});
                  },
                ),
              ),
            ),
            if (ctl.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(invOk
                    ? [
                        '${app.inviteStageName(inv)} · ${ui.t('difficulty.${inv.difficulty.name}')}',
                        if (inv.hasResult) ui.t('invite.beat', {'mark': inv.won! ? '✅' : '❌', 'hp': inv.baseHp!}),
                        if (!invPlayable) ui.t('invite.locked'),
                      ].join('\n')
                    : ok
                        ? '${app.s.regionName(r.stageId)} · ${ui.t('difficulty.${r.difficulty.name}')}  ${r.result.won ? '✅' : '❌'} ♥${r.result.baseHp}'
                        : ctl.text.contains('TMI1') ? ui.t('invite.invalid') : ui.t('replay.invalid')),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ui.t('result.back'))),
            if (ok)
              TextButton(
                key: const ValueKey('challenge-watch'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _watch(r);
                },
                child: Text(ui.t('replay.watch')),
              ),
            FilledButton(
              key: const ValueKey('challenge-play'),
              onPressed: invPlayable
                  ? () {
                      Navigator.pop(ctx);
                      _play(inv.kind, inv.stageId, difficulty: inv.difficulty);
                    }
                  : ok && r.kind == StageKind.normal && isRegionUnlocked(r.stageId, premium: premium)
                      ? () {
                          Navigator.pop(ctx);
                          _play(r.kind, r.stageId, difficulty: r.difficulty);
                        }
                      : null,
              child: Text(ui.t('stage.play')),
            ),
          ],
        );
      }),
    );
  }

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
      appBar: AppBar(title: Text(s.t('battle')), actions: [
        IconButton(
          key: const ValueKey('collection'),
          tooltip: ui.t('collection.title'),
          icon: Badge(
            isLabelVisible: widget.app.newCardCount > 0,
            label: Text('${widget.app.newCardCount}'),
            child: const Icon(Icons.collections_bookmark),
          ),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CollectionScreen(app: widget.app))),
        ),
        IconButton(
          key: const ValueKey('achievements'),
          tooltip: ui.t('ach.title'),
          icon: Badge(
            isLabelVisible: widget.app.newAchievementCount > 0,
            label: Text('${widget.app.newAchievementCount}'),
            child: const Icon(Icons.emoji_events),
          ),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AchievementsScreen(app: widget.app))),
        ),
        IconButton(key: const ValueKey('challenge'), tooltip: ui.t('daily.challenge'), icon: const Icon(Icons.link), onPressed: _challengeDialog),
      ]),
      body: SafeArea(
        child: Column(children: [
          _dailyCard(premium),
          _weeklyCard(premium),
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
          // 長押しで、このステージ（今選んでいる難易度）への招待をコピーする
          onLongPress: () async {
            final inv = Invite(packId: app.pack.packId, kind: StageKind.normal, stageId: id, difficulty: _difficulty);
            await Clipboard.setData(ClipboardData(text: app.inviteText(inv)));
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ui.t('invite.copied')), duration: const Duration(seconds: 2)));
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

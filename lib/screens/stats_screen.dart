import 'package:flutter/material.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/progress/weekly_goal.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';

import '../app_state.dart';
import '../share_card.dart';
import 'quiz_screen.dart';

/// 統計。クイズ・バトル・毎日のバトル・図鑑・実績の数字を、今ある記録から出す。
class StatsScreen extends StatelessWidget {
  final AppState app;
  const StatsScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: _build);

  Widget _build(BuildContext context, Widget? _) {
    final ui = app.ui, st = app.stats;
    Widget bar(String key, int n, int total, {String? label}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(label ?? ui.t(key))),
              Text('$n / $total', key: ValueKey('$key-value'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: total == 0 ? 0 : (n / total).clamp(0.0, 1.0)),
          ]),
        );
    Widget line(String key, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(ui.t(key))),
            Text(value, key: ValueKey('$key-value'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        );
    Widget section(String key, List<Widget> children) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ui.t(key), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              ...children,
            ]),
          ),
        );
    String playTime() {
      final m = st.playMinutes;
      return m < 60 ? ui.t('stats.minutes', {'n': m}) : ui.t('stats.hoursMinutes', {'h': m ~/ 60, 'm': m % 60});
    }
    String days(int n) => ui.t('stats.days', {'n': n});
    return Scaffold(
      appBar: AppBar(title: Text(ui.t('stats.title')), actions: [
        IconButton(
          key: const ValueKey('stats-share'),
          tooltip: ui.t('share.send'),
          icon: const Icon(Icons.ios_share),
          onPressed: () => showShareCard(
            context,
            app,
            ShareCardData(
              heading: ui.t('share.progressTitle'),
              title: app.s.t('appTitle'),
              rows: [
                (ui.t('stats.mastered'), '${st.quizMastered} / ${st.quizTotal}'),
                (ui.t('stats.streakBest'), days(st.streakBest)),
                (ui.t('stats.winRate'), st.winRatePercent == null ? '—' : '${st.winRatePercent}%'),
                (ui.t('stats.cards'), '${st.cardsUnlocked} / ${st.cardsTotal}'),
                (ui.t('stats.achievements'), '${st.achievementsUnlocked} / ${st.achievementsTotal}'),
              ],
            ),
          ),
        ),
      ]),
      body: ListView(
        key: const ValueKey('stats-list'),
        padding: const EdgeInsets.all(12),
        children: [
          section('goal.title', [
            bar('goal.progress', app.weeklyGoal.shown, app.weeklyGoal.target, label: ui.t('goal.progress', {'n': app.weeklyGoal.answered, 'total': app.weeklyGoal.target})),
            if (app.weeklyGoal.reached)
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(ui.t('goal.reached'), key: const ValueKey('goal-reached'))),
            const SizedBox(height: 4),
            Text(ui.t('goal.set'), style: Theme.of(context).textTheme.bodySmall),
            Wrap(spacing: 8, children: [
              for (final n in WeeklyGoal.choices)
                ChoiceChip(
                  key: ValueKey('goal-$n'),
                  label: Text('$n'),
                  selected: app.weeklyGoalTarget == n,
                  onSelected: (_) => app.setWeeklyGoalTarget(n),
                ),
            ]),
          ]),
          section('stats.quiz', [
            bar('stats.mastered', st.quizMastered, st.quizTotal),
            line('stats.missed', '${st.quizMissed}'),
            line('stats.unseen', '${st.quizUnseen}'),
          ]),
          section('stats.trend', [
            _Trend(app: app, key: const ValueKey('stats-trend')),
          ]),
          section('stats.weak', [
            if (app.weakRegions.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(ui.t('stats.weakNone'), key: const ValueKey('weak-none'))),
            for (final w in app.weakRegions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(child: Text(app.s.regionName(w.id), key: ValueKey('weak-${w.id}'))),
                  Text(w.mastered ? '${ui.t('stats.weakMisses', {'n': w.misses})} · ${ui.t('stats.weakMastered')}' : ui.t('stats.weakMisses', {'n': w.misses}),
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            if (app.weakRegions.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('weak-review'),
                  icon: const Icon(Icons.replay),
                  label: Text(ui.t('stats.weakReview')),
                  onPressed: () {
                    final qs = QuizEngine(app.pack, seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF)
                        .generate(count: 10, types: QuestionType.values, pool: {for (final w in app.weakRegions) w.id});
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(app: app, questions: qs)));
                  },
                ),
              ),
          ]),
          section('stats.battle', [
            bar('stats.clearedEasy', st.statesCleared[Difficulty.easy] ?? 0, st.totalStates),
            bar('stats.clearedNormal', st.statesCleared[Difficulty.normal] ?? 0, st.totalStates),
            bar('stats.clearedHard', st.statesCleared[Difficulty.hard] ?? 0, st.totalStates),
            if (st.regionalTotal > 0) bar('stats.regional', st.regionalCleared, st.regionalTotal),
            if (st.extraTotal > 0) bar('stats.extra', st.extraCleared, st.extraTotal),
          ]),
          section('stats.record', [
            line('stats.wins', '${st.wins}'),
            line('stats.losses', '${st.losses}'),
            line('stats.winRate', st.winRatePercent == null ? '—' : '${st.winRatePercent}%'),
            line('stats.playTime', playTime()),
          ]),
          section('stats.daily', [
            line('stats.streakNow', days(st.streakCurrent)),
            line('stats.streakBest', days(st.streakBest)),
          ]),
          section('stats.collect', [
            bar('stats.cards', st.cardsUnlocked, st.cardsTotal),
            bar('stats.achievements', st.achievementsUnlocked, st.achievementsTotal),
          ]),
        ],
      ),
    );
  }
}

/// 週ごとの正答率の棒グラフ（古い週が左、今週が右）。クイズをまだ解いていなければ案内を出す。
class _Trend extends StatelessWidget {
  final AppState app;
  const _Trend({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final ui = app.ui;
    final h = app.quizHistory;
    if (h.totalAnswers == 0) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(ui.t('stats.trendEmpty'), key: const ValueKey('trend-empty')));
    }
    final weeks = h.weekly(app.today());
    final color = Theme.of(context).colorScheme.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 110,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < weeks.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(weeks[i].accuracyPercent == null ? '' : '${weeks[i].accuracyPercent}', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Container(
                    key: ValueKey('trend-bar-$i'),
                    height: 4 + 80 * ((weeks[i].accuracyPercent ?? 0) / 100),
                    decoration: BoxDecoration(
                      color: weeks[i].accuracyPercent == null ? Colors.grey.withValues(alpha: 0.3) : color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      Text(ui.t('stats.trendHelp'), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

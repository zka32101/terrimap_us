import 'package:flutter/material.dart';
import 'package:terrimap_core/battle/difficulty.dart';

import '../app_state.dart';

/// 統計。クイズ・バトル・毎日のバトル・図鑑・実績の数字を、今ある記録から出す。
class StatsScreen extends StatelessWidget {
  final AppState app;
  const StatsScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
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
    String days(int n) => ui.t('stats.days', {'n': n});
    return Scaffold(
      appBar: AppBar(title: Text(ui.t('stats.title'))),
      body: ListView(
        key: const ValueKey('stats-list'),
        padding: const EdgeInsets.all(12),
        children: [
          section('stats.quiz', [
            bar('stats.mastered', st.quizMastered, st.quizTotal),
            line('stats.missed', '${st.quizMissed}'),
            line('stats.unseen', '${st.quizUnseen}'),
          ]),
          section('stats.battle', [
            bar('stats.clearedEasy', st.statesCleared[Difficulty.easy] ?? 0, st.totalStates),
            bar('stats.clearedNormal', st.statesCleared[Difficulty.normal] ?? 0, st.totalStates),
            bar('stats.clearedHard', st.statesCleared[Difficulty.hard] ?? 0, st.totalStates),
            if (st.regionalTotal > 0) bar('stats.regional', st.regionalCleared, st.regionalTotal),
            if (st.extraTotal > 0) bar('stats.extra', st.extraCleared, st.extraTotal),
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

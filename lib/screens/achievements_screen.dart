import 'package:flutter/material.dart';

import '../app_state.dart';

/// 実績。クリア・連続日数・図鑑などから、毎回計算する。
class AchievementsScreen extends StatefulWidget {
  final AppState app;
  const AchievementsScreen({super.key, required this.app});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final Set<String> _seenAtOpen = widget.app.seenAchievements; // 開いたときの「見たことのある実績」（NEW の判定）

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.app.markAchievementsSeen());
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app, ui = app.ui;
    final list = app.achievements.all;
    final done = list.where((a) => a.unlocked).length;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${ui.t('ach.title')}  ${ui.t('ach.count', {'n': done, 'total': list.length})}')),
      body: GridView.builder(
        key: const ValueKey('achievements-grid'),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.8),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final a = list[i];
          final isNew = a.unlocked && !_seenAtOpen.contains(a.id);
          return Card(
            key: ValueKey('ach-${a.id}'),
            color: a.unlocked ? null : scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (isNew) Text(ui.t('ach.newBadge'), style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
                Icon(a.unlocked ? Icons.emoji_events : Icons.lock_outline, size: 32, color: a.unlocked ? Colors.amber.shade700 : null),
                const SizedBox(height: 6),
                Text(ui.t('ach.${a.id}'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(ui.t('ach.${a.id}.desc'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: a.ratio),
                const SizedBox(height: 2),
                Text('${a.shown}/${a.goal}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          );
        },
      ),
    );
  }
}

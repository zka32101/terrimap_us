import 'package:flutter/material.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/endless.dart';

import '../app_state.dart';
import '../monetization.dart';
import 'battle_screen.dart';
import 'story_screen.dart';
import 'unlock_sheet.dart';

/// エンドレス。州をえらんで、できるだけ長く守る。州ごとの自己ベストを並べる(上位が上)。
class EndlessScreen extends StatelessWidget {
  final AppState app;
  final bool premium;
  const EndlessScreen({super.key, required this.app, required this.premium});

  @override
  Widget build(BuildContext context) {
    final s = app.s;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final board = app.endless;
        final ids = [for (final r in app.pack.regions) r.id]..sort((a, b) {
            final ra = board.bestOf(a)?.rank ?? -1, rb = board.bestOf(b)?.rank ?? -1;
            return ra != rb ? rb.compareTo(ra) : s.regionName(a).compareTo(s.regionName(b));
          });
        final today = EndlessDaily.regionFor(app.pack, app.today(), allowedIds: premium ? null : freeRegionIds);
        final story = app.story;
        final best = app.endlessBestWaves;
        return Scaffold(
          appBar: AppBar(title: Text(s.t('endless.title'))),
          body: SafeArea(
            child: ListView(children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(s.t('endless.intro'))),
              Card(
                key: const ValueKey('endless-today'),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ListTile(
                  leading: const Icon(Icons.today),
                  title: Text('${s.t('endless.today')}: ${s.regionName(today)}'),
                  subtitle: Text(board.bestOf(today) == null ? s.t('endless.none') : s.t('endless.best').replaceAll('{n}', '${board.bestOf(today)!.waves}')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _play(context, today),
                ),
              ),
              if (story != null && story.epilogues.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(s.t('endless.storyTitle'), style: Theme.of(context).textTheme.titleSmall)),
                for (final e in story.epilogues)
                  ListTile(
                    key: ValueKey('epilogue-${e.waves}'),
                    leading: Icon(e.waves <= best ? Icons.menu_book : Icons.lock_outline),
                    title: Text(e.waves <= best ? e.title.of(app.lang) : s.t('endless.storyLocked').replaceAll('{n}', '${e.waves}')),
                    onTap: e.waves <= best ? () => showStoryLines(context, app, title: e.title.of(app.lang), lines: e.lines) : null,
                  ),
                const Divider(),
              ],
              for (final id in ids)
                ListTile(
                  key: ValueKey('endless-$id'),
                  title: Text(s.regionName(id)),
                  subtitle: Text(board.bestOf(id) == null ? s.t('endless.none') : s.t('endless.best').replaceAll('{n}', '${board.bestOf(id)!.waves}')),
                  trailing: isRegionUnlocked(id, premium: premium) ? const Icon(Icons.chevron_right) : const Icon(Icons.lock_outline),
                  onTap: () {
                    if (!isRegionUnlocked(id, premium: premium)) {
                      showUnlockSheet(context, app);
                      return;
                    }
                    _play(context, id);
                  },
                ),
            ]),
          ),
        );
      },
    );
  }

  void _play(BuildContext context, String id) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BattleScreen(app: app, regionId: id, difficulty: Difficulty.normal, endless: true),
      ));
}

import 'package:flutter/material.dart';
import 'package:terrimap_core/battle/difficulty.dart';

import '../app_state.dart';
import '../monetization.dart';
import 'battle_screen.dart';
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
        return Scaffold(
          appBar: AppBar(title: Text(s.t('endless.title'))),
          body: SafeArea(
            child: ListView(children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(s.t('endless.intro'))),
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
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BattleScreen(app: app, regionId: id, difficulty: Difficulty.normal, endless: true),
                    ));
                  },
                ),
            ]),
          ),
        );
      },
    );
  }
}

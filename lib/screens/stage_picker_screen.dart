import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terrimap_core/battle/difficulty.dart';

import '../app_state.dart';
import '../monetization.dart';
import 'battle_screen.dart';
import 'unlock_sheet.dart';

/// 守る州と難易度を選ぶ画面。無料の州以外は、解放の案内を出す。
class StagePickerScreen extends ConsumerStatefulWidget {
  final AppState app;
  const StagePickerScreen({super.key, required this.app});
  @override
  ConsumerState<StagePickerScreen> createState() => _StagePickerState();
}

class _StagePickerState extends ConsumerState<StagePickerScreen> {
  Difficulty _difficulty = Difficulty.normal;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final s = app.s, ui = app.ui;
    final service = ref.watch(entitlementServiceProvider);
    final premium = ref.watch(entitlementStateProvider).valueOrNull?.hasPremium ?? service.state.hasPremium;
    final ids = [for (final r in app.pack.regions) r.id]..sort((a, b) => s.regionName(a).compareTo(s.regionName(b)));
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(ui.t('stage.choose'), style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: ListView(children: [
              for (final id in ids)
                ListTile(
                  key: ValueKey('stage-$id'),
                  title: Text(s.regionName(id)),
                  subtitle: Text(ui.t('stage.base', {'capital': s.capitalName(id)})),
                  trailing: isRegionUnlocked(id, premium: premium) ? const Icon(Icons.chevron_right) : const Icon(Icons.lock_outline),
                  onTap: () {
                    if (!isRegionUnlocked(id, premium: premium)) {
                      showUnlockSheet(context, app);
                      return;
                    }
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BattleScreen(app: app, regionId: id, difficulty: _difficulty),
                    ));
                  },
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

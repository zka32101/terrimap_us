import 'package:flutter/material.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/progress/region_progress.dart';

import '../app_state.dart';
import 'region_guide_screen.dart';
import 'story_screen.dart';

/// 旅の手帳。州ごとのスタンプ帳。クイズで覚えた州と、バトルでクリアした州にスタンプが押される。
/// スタンプを押した州のページでは、主人公のひとことと、その州で覚えた名所・名物が読める。
class NotebookScreen extends StatelessWidget {
  final AppState app;
  const NotebookScreen({super.key, required this.app});

  /// 主人公のひとことの文言の数（`notebook.hero.0`〜）。
  static const heroLineCount = 4;

  /// その州のスタンプを押したか(クイズで覚えた、または州のバトルをクリアした)。
  static bool stamped(AppState app, String regionId) =>
      app.progress.stateOf(regionId) == RegionState.mastered || app.battle.isCleared(StageKind.normal, regionId);

  /// 州ごとに決まったひとこと(同じ州はいつも同じ文)。州の id から選ぶ。
  static int heroLineIndex(String regionId) => regionId.codeUnits.fold<int>(0, (a, c) => a + c) % heroLineCount;

  static int stampedCount(AppState app) => app.pack.regions.where((r) => stamped(app, r.id)).length;

  void _openPage(BuildContext context, String regionId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NotebookPage(app: app, regionId: regionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = app.s;
    final regions = [...app.pack.regions]..sort((a, b) => s.regionName(a.id).compareTo(s.regionName(b.id)));
    return Scaffold(
      appBar: AppBar(title: Text('${s.t('notebook.title')}  ${stampedCount(app)} / ${regions.length}')),
      body: GridView.builder(
        key: const ValueKey('notebook-grid'),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 130, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1),
        itemCount: regions.length,
        itemBuilder: (context, i) {
          final r = regions[i];
          final done = stamped(app, r.id);
          final scheme = Theme.of(context).colorScheme;
          return Card(
            key: ValueKey('stamp-${r.id}'),
            color: done ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: done ? () => _openPage(context, r.id) : null,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(done ? Icons.verified : Icons.circle_outlined, color: done ? scheme.tertiary : scheme.outline, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    done ? s.regionName(r.id) : '？',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotebookPage extends StatelessWidget {
  final AppState app;
  final String regionId;
  const _NotebookPage({required this.app, required this.regionId});

  @override
  Widget build(BuildContext context) {
    final s = app.s, theme = Theme.of(context);
    final hero = app.story?.hero;
    final region = s.regionName(regionId);
    final heroLine = s.t('notebook.hero.${NotebookScreen.heroLineIndex(regionId)}');
    final landmarks = [for (final l in app.pack.facts?.inRegion(regionId) ?? const []) l.nameIn(app.lang)];
    final known = [for (final k in app.pack.facts?.knowledgeIn(regionId) ?? const []) k.nameIn(app.lang)];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(region, key: const ValueKey('notebook-page-title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${s.t('notebook.capital')}: ${s.capitalName(regionId)}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('notebook-hero-line'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (hero != null) ...[HeroAvatar(hero: hero, lang: app.lang, look: app.activeLook), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (hero != null) Text(hero.name.of(app.lang), style: theme.textTheme.labelLarge),
                  Text(heroLine, style: theme.textTheme.bodyLarge),
                ]),
              ),
            ]),
          ),
          if (landmarks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.t('notebook.landmarks'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(landmarks.join(' · '), key: const ValueKey('notebook-landmarks')),
          ],
          if (known.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.t('notebook.knowledge'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(known.join(' · '), key: const ValueKey('notebook-knowledge')),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('notebook-guide'),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(s.t('guide.open')),
              onPressed: () {
                Navigator.pop(context);
                openRegionGuide(context, app, regionId);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

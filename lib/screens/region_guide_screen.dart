import 'package:flutter/material.dart';
import 'package:terrimap_core/map/region_silhouette.dart';
import 'package:terrimap_core/pack/country_profile.dart';

import '../app_state.dart';
import 'landmark_detail.dart';

/// 州の解説ページ。形・州都・紹介文・地方・となりの州・名所・名物をひとつにまとめる（新しい事実は持たず、データを並べる）。
class RegionGuideScreen extends StatelessWidget {
  final AppState app;
  final String regionId;
  const RegionGuideScreen({super.key, required this.app, required this.regionId});

  /// その州が入っている地方の名前（地方がない国・入っていない州は null）。
  String? get _groupName {
    final groups = app.pack.profile?.groups.values ?? const <RegionGroup>[];
    for (final g in groups) {
      if (g.regions.contains(regionId)) return g.name[app.lang] ?? g.name['en'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = app.s, theme = Theme.of(context);
    final region = app.pack.regions.firstWhere((r) => r.id == regionId);
    final blurb = app.pack.profile?.traitOf(regionId).blurbIn(app.lang) ?? '';
    final group = _groupName;
    final neighbors = [for (final n in region.neighbors) s.regionName(n)]..sort();
    final landmarks = app.pack.facts?.inRegion(regionId) ?? const [];
    final known = [for (final k in app.pack.facts?.knowledgeIn(regionId) ?? const []) k.nameIn(app.lang)];
    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            child,
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: Text(s.regionName(regionId), key: const ValueKey('guide-title'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(
            height: 180,
            child: Semantics(
              image: true,
              label: s.regionName(regionId),
              child: RegionSilhouette(pack: app.pack, regionId: regionId, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text('${s.t('notebook.capital')}: ${s.capitalName(regionId)}', style: theme.textTheme.titleMedium),
          if (blurb.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              key: const ValueKey('guide-blurb'),
              child: Padding(padding: const EdgeInsets.all(14), child: Text(blurb, style: theme.textTheme.bodyLarge)),
            ),
          ],
          if (group != null) section(s.t('guide.group'), Text(group, key: const ValueKey('guide-group'))),
          if (neighbors.isNotEmpty) section(s.t('guide.neighbors'), Text(neighbors.join(' · '), key: const ValueKey('guide-neighbors'))),
          if (landmarks.isNotEmpty)
            section(
              s.t('notebook.landmarks'),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final l in landmarks)
                  ActionChip(
                    key: ValueKey('guide-landmark-${l.id}'),
                    label: Text(l.nameIn(app.lang)),
                    onPressed: () => showLandmarkDetail(context, app, l.id),
                  ),
              ]),
            ),
          if (known.isNotEmpty) section(s.t('notebook.knowledge'), Text(known.join(' · '), key: const ValueKey('guide-knowledge'))),
        ]),
      ),
    );
  }
}

/// 解説ページを開く（州の地図のシート・クイズの結果から）。
void openRegionGuide(BuildContext context, AppState app, String regionId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegionGuideScreen(app: app, regionId: regionId)));

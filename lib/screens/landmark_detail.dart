import 'package:flutter/material.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';

import '../app_state.dart';
import 'region_guide_screen.dart';

/// 名所の詳細。大きな画像と、名前・州を見せる（説明文は持たない）。
Future<void> showLandmarkDetail(BuildContext context, AppState app, String landmarkId, {ArtSet? art}) async {
  final lm = app.pack.facts?.landmarks.where((l) => l.id == landmarkId).firstOrNull;
  if (lm == null) return;
  final a = art ?? await app.art().catchError((_) => const ArtSet());
  if (!context.mounted) return;
  final img = a.landmark(lm.id);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('landmark-detail'),
      title: Text(lm.nameIn(app.lang)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 280,
          height: 280,
          child: img == null
              ? const Icon(Icons.place, size: 64)
              : Semantics(image: true, label: app.ui.t('a11y.landmarkImage', {'name': lm.nameIn(app.lang)}), child: RawImage(image: img, fit: BoxFit.contain)),
        ),
        const SizedBox(height: 12),
        Text(app.ui.t('landmark.in', {'region': app.s.regionName(lm.regionId)})),
      ]),
      actions: [
        TextButton(
          key: const ValueKey('landmark-guide'),
          onPressed: () {
            Navigator.pop(ctx);
            openRegionGuide(context, app, lm.regionId);
          },
          child: Text(app.s.t('guide.open')),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.s.t('home'))),
      ],
    ),
  );
}

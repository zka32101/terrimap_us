import 'package:flutter/material.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_core/daily/daily_landmark.dart';

import '../app_state.dart';
import '../share_card.dart';
import 'landmark_detail.dart';

/// ホームの「今日の名所」。日替わりで、名所の画像・名前・州を見せる。名所のデータがなければ何も出さない。
class DailyLandmarkCard extends StatefulWidget {
  final AppState app;
  final ArtSet? art; // テスト用に差し替えられる
  const DailyLandmarkCard({super.key, required this.app, this.art});
  @override
  State<DailyLandmarkCard> createState() => _DailyLandmarkCardState();
}

class _DailyLandmarkCardState extends State<DailyLandmarkCard> {
  ArtSet? _art;

  @override
  void initState() {
    super.initState();
    _art = widget.art;
    if (_art == null) {
      widget.app.art().then((a) {
        if (mounted) setState(() => _art = a);
      }, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final lm = DailyLandmark.pick(app.pack.facts, app.today());
    if (lm == null) return const SizedBox.shrink();
    final img = _art?.landmark(lm.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        key: const ValueKey('daily-landmark'),
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: () => showLandmarkDetail(context, app, lm.id, art: _art),
          leading: SizedBox(
            width: 48,
            height: 48,
            child: img == null ? const Icon(Icons.place) : RawImage(image: img, fit: BoxFit.contain),
          ),
          trailing: IconButton(
            key: const ValueKey('daily-landmark-share'),
            tooltip: app.ui.t('share.send'),
            icon: const Icon(Icons.ios_share),
            onPressed: () => showShareCard(
              context,
              app,
              ShareCardData(
                heading: app.ui.t('dailyLandmark.title'),
                title: lm.nameIn(app.lang),
                subtitle: app.ui.t('landmark.in', {'region': app.s.regionName(lm.regionId)}),
                image: img,
              ),
            ),
          ),
          title: Text(app.ui.t('dailyLandmark.title'), style: Theme.of(context).textTheme.labelMedium),
          subtitle: Text(
            app.ui.t('dailyLandmark.in', {'name': lm.nameIn(app.lang), 'region': app.s.regionName(lm.regionId)}),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

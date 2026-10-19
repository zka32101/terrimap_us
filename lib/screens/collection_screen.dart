import 'package:flutter/material.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';

import 'package:terrimap_core/battle/collection.dart';

import '../app_state.dart';
import 'landmark_detail.dart';

/// 名所のコレクション。州をクリアすると、その州の名所カードが集まる。
class CollectionScreen extends StatefulWidget {
  final AppState app;
  final ArtSet? art; // 名所の画像（省略するとアプリの `assets/art/landmarks/` から読む。テスト用に差し替えられる）
  const CollectionScreen({super.key, required this.app, this.art});
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final Set<String> _seenAtOpen = widget.app.seenCards; // 開いたときの「見たことのあるカード」（NEW の判定）

  ArtSet? _art;

  @override
  void initState() {
    super.initState();
    _art = widget.art;
    if (_art == null) {
      widget.app.art().then((a) {
        if (mounted) setState(() => _art = a);
      }, onError: (_) {}); // 画像が読めなくても、アイコンで出す
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.app.markCardsSeen());
  }

  /// カードの絵。解放済みで名所の画像があれば画像、なければアイコン（未解放は鍵）。
  Widget _picture(CollectionCard c) {
    final img = c.unlocked ? _art?.landmark(c.landmark.id) : null;
    if (img == null) return Icon(c.unlocked ? Icons.place : Icons.lock_outline, size: 32);
    return SizedBox(key: ValueKey('card-image-${c.landmark.id}'), width: 64, height: 64, child: RawImage(image: img, fit: BoxFit.contain));
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app, ui = app.ui;
    final col = app.collection;
    final cards = col.cards;
    return Scaffold(
      appBar: AppBar(title: Text('${ui.t('collection.title')}  ${ui.t('collection.count', {'n': col.unlockedCount, 'total': col.total})}')),
      body: cards.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(ui.t('collection.empty'))))
          : GridView.builder(
              key: const ValueKey('collection-grid'),
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78),
              itemCount: cards.length,
              itemBuilder: (_, i) {
                final c = cards[i];
                final region = app.s.regionName(c.landmark.regionId);
                final isNew = c.unlocked && !_seenAtOpen.contains(c.landmark.id);
                return Card(
                  key: ValueKey('card-${c.landmark.id}'),
                  color: c.unlocked ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: c.unlocked ? () => showLandmarkDetail(context, app, c.landmark.id, art: _art) : null,
                    child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (isNew) Text(ui.t('collection.newBadge'), style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
                      _picture(c),
                      const SizedBox(height: 6),
                      Text(
                        c.unlocked ? c.landmark.nameIn(app.lang) : '？',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.unlocked ? region : ui.t('collection.locked', {'name': region}),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
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

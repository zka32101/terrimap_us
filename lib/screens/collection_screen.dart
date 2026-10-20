import 'package:flutter/material.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';

import 'package:terrimap_core/battle/collection.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/story/story.dart';

import '../app_state.dart';
import 'landmark_detail.dart';
import 'notebook_screen.dart';
import 'story_screen.dart';

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

  /// 名所カード1枚。
  Widget _landmarkCard(CollectionCard c) {
    final app = widget.app, ui = app.ui;
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
  }

  /// 物語カード1枚。章を終えると集まり、タップで読み返せる。エクストラはボスの絵、地方決戦は地図のアイコン。
  Widget _storyCard(StoryProgress sp, StoryChapter ch) {
    final app = widget.app, lang = app.lang;
    final done = sp.completed(ch);
    final img = done && ch.kind == StageKind.extra ? _art?.images['bosses/${ch.stageId}'] : null;
    final Widget picture = img != null
        ? SizedBox(key: ValueKey('story-card-image-${ch.id}'), width: 64, height: 64, child: RawImage(image: img, fit: BoxFit.contain))
        : Icon(!done ? Icons.lock_outline : ch.kind == StageKind.extra ? Icons.auto_stories : Icons.map_outlined, size: 32);
    return Card(
      key: ValueKey('story-card-${ch.id}'),
      color: done ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: done ? () => showStoryLines(context, app, title: ch.title.of(lang), lines: [...ch.intro, ...ch.beforeBoss, ...ch.outro]) : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            picture,
            const SizedBox(height: 6),
            Text(
              done ? ch.title.of(lang) : '？',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app, ui = app.ui;
    final col = app.collection;
    final cards = col.cards;
    final sp = app.storyProgress;
    return Scaffold(
      appBar: AppBar(title: Text('${ui.t('collection.title')}  ${ui.t('collection.count', {'n': col.unlockedCount, 'total': col.total})}')),
      body: CustomScrollView(
              key: const ValueKey('collection-grid'),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Card(
                      child: ListTile(
                        key: const ValueKey('notebook-entry'),
                        leading: const Icon(Icons.menu_book),
                        title: Text('${app.s.t('notebook.title')}  ${NotebookScreen.stampedCount(app)} / ${app.pack.regions.length}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotebookScreen(app: app))),
                      ),
                    ),
                  ),
                ),
                if (cards.isEmpty)
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24), child: Text(ui.t('collection.empty'))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78),
                      itemCount: cards.length,
                      itemBuilder: (_, i) => _landmarkCard(cards[i]),
                    ),
                  ),
                if (sp != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text('${ui.t('story.title')}  ${sp.completedCount} / ${sp.story.chapters.length}',
                          key: const ValueKey('story-cards-title'), style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78),
                      itemCount: sp.story.chapters.length,
                      itemBuilder: (_, i) => _storyCard(sp, sp.story.chapters[i]),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

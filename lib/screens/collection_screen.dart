import 'package:flutter/material.dart';

import '../app_state.dart';

/// 名所のコレクション。州をクリアすると、その州の名所カードが集まる。
class CollectionScreen extends StatefulWidget {
  final AppState app;
  const CollectionScreen({super.key, required this.app});
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final Set<String> _seenAtOpen = widget.app.seenCards; // 開いたときの「見たことのあるカード」（NEW の判定）

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.app.markCardsSeen());
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
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (isNew) Text(ui.t('collection.newBadge'), style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
                      Icon(c.unlocked ? Icons.place : Icons.lock_outline, size: 32),
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
                );
              },
            ),
    );
  }
}

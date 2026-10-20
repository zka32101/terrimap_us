import 'package:flutter/material.dart';
import 'package:terrimap_core/story/story.dart';

import '../app_state.dart';

/// 章のせりふを1つずつ出して、読み終えたら閉じる（戦いの前後と、物語の画面で使う）。
Future<void> showStoryLines(BuildContext context, AppState app, {required String title, required List<DialogueLine> lines}) {
  if (lines.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _StorySheet(app: app, title: title, lines: lines),
  );
}

class _StorySheet extends StatefulWidget {
  final AppState app;
  final String title;
  final List<DialogueLine> lines;
  const _StorySheet({required this.app, required this.title, required this.lines});
  @override
  State<_StorySheet> createState() => _StorySheetState();
}

class _StorySheetState extends State<_StorySheet> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final ui = widget.app.ui, lang = widget.app.lang;
    final line = widget.lines[_i];
    final last = _i == widget.lines.length - 1;
    final theme = Theme.of(context);
    final isNote = line.speaker == Speaker.note;
    final isBoss = line.speaker == Speaker.boss;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('story-line'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isNote ? theme.colorScheme.surfaceContainerHighest : isBoss ? theme.colorScheme.errorContainer : theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isBoss ? '「${line.text.of(lang)}」' : line.text.of(lang),
              style: theme.textTheme.bodyLarge?.copyWith(fontStyle: isNote ? FontStyle.italic : null),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('${_i + 1} / ${widget.lines.length}', style: theme.textTheme.labelMedium),
            const Spacer(),
            FilledButton(
              key: const ValueKey('story-next'),
              onPressed: () => last ? Navigator.pop(context) : setState(() => _i++),
              child: Text(ui.t(last ? 'story.done' : 'story.next')),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// 物語の章の一覧。終えた章は読み返せる。前の章を終えるまでは鍵つき。
class StoryScreen extends StatelessWidget {
  final AppState app;
  const StoryScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final ui = app.ui, lang = app.lang;
    final sp = app.storyProgress;
    return Scaffold(
      appBar: AppBar(title: Text(ui.t('story.title'))),
      body: sp == null
          ? const SizedBox.shrink()
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('${sp.completedCount} / ${sp.story.chapters.length}', key: const ValueKey('story-count')),
              const SizedBox(height: 8),
              for (final c in sp.story.chapters)
                Card(
                  child: ListTile(
                    key: ValueKey('chapter-${c.id}'),
                    leading: Icon(sp.completed(c) ? Icons.check_circle : sp.unlocked(c) ? Icons.menu_book : Icons.lock_outline),
                    title: Text(c.title.of(lang)),
                    subtitle: Text(sp.completed(c) ? ui.t('story.cleared') : sp.unlocked(c) ? '' : ui.t('story.locked')),
                    onTap: !sp.unlocked(c)
                        ? null
                        : () => showStoryLines(context, app,
                            title: c.title.of(lang), lines: [...c.intro, ...c.beforeBoss, if (sp.completed(c)) ...c.outro]),
                  ),
                ),
            ]),
    );
  }
}

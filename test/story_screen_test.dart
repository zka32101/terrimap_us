import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/screens/story_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('物語: 章の一覧が出て、読むと最後に「おわり」で閉じる。クリアすると「クリア済み」', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    expect(app.story, isNotNull);
    expect(app.story!.validate(app.pack), isEmpty); // 同梱の物語データに問題がない
    await t.pumpWidget(MaterialApp(home: StoryScreen(app: app)));
    final ch = app.story!.chapters.first;
    expect(find.text(ch.title.of('en')), findsOneWidget);
    expect(find.text('0 / ${app.story!.chapters.length}'), findsOneWidget);

    await t.tap(find.byKey(ValueKey('chapter-${ch.id}')));
    await t.pumpAndSettle();
    final total = ch.intro.length + ch.beforeBoss.length;
    for (var i = 0; i < total - 1; i++) {
      await t.tap(find.byKey(const ValueKey('story-next')));
      await t.pumpAndSettle();
    }
    await t.tap(find.byKey(const ValueKey('story-next'))); // 最後は閉じる
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('story-line')), findsNothing);

    await app.recordBattleClear(ch.kind, ch.stageId, Difficulty.easy);
    await t.pumpWidget(MaterialApp(home: StoryScreen(app: app)));
    expect(find.text('1 / ${app.story!.chapters.length}'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  test('物語: 章のステージが取れる', () async {
    final app = await AppState.load();
    final c = app.story!.forStage(StageKind.extra, 'us_bunyan');
    expect(c, isNotNull);
  });
}

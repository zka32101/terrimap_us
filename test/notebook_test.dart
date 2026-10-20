import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/screens/collection_screen.dart';
import 'package:terrimap_us/screens/notebook_screen.dart';
import 'package:terrimap_us/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('文言: 手帳の文言と主人公のひとことが全言語にある。ひとことの選び方は州ごとに決まっている', () async {
    final app = await AppState.load();
    for (final lang in Strings.supported) {
      await app.setLang(lang);
      for (final k in ['notebook.title', 'notebook.capital', 'notebook.landmarks', 'notebook.knowledge']) {
        expect(app.s.t(k), isNot(k), reason: '$lang $k');
      }
      for (var i = 0; i < NotebookScreen.heroLineCount; i++) {
        expect(app.s.t('notebook.hero.$i'), isNot('notebook.hero.$i'), reason: '$lang $i');
      }
    }
    for (final r in app.pack.regions) {
      final i = NotebookScreen.heroLineIndex(r.id);
      expect(i, inInclusiveRange(0, NotebookScreen.heroLineCount - 1));
      expect(NotebookScreen.heroLineIndex(r.id), i);
    }
  });

  test('スタンプ: 最初は0。バトルでクリアした州に押される', () async {
    final app = await AppState.load();
    expect(NotebookScreen.stampedCount(app), 0);
    await app.recordBattleClear(StageKind.normal, 'US-CA', Difficulty.easy);
    expect(NotebookScreen.stamped(app, 'US-CA'), isTrue);
    expect(NotebookScreen.stamped(app, 'US-NY'), isFalse);
    expect(NotebookScreen.stampedCount(app), 1);
  });

  testWidgets('手帳: 図鑑から開ける。スタンプのない州は？で押せず、押した州のページに主人公のひとことと名所・名物が出る', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await app.recordBattleClear(StageKind.normal, 'US-CA', Difficulty.easy);
    await t.pumpWidget(MaterialApp(home: CollectionScreen(app: app)));
    await t.pump();
    expect(find.text('${app.s.t('notebook.title')}  1 / ${app.pack.regions.length}'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('notebook-entry')));
    await t.pumpAndSettle();
    expect(find.text('？'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('stamp-US-NY'))); // スタンプなし
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('notebook-page-title')), findsNothing);

    await t.tap(find.byKey(const ValueKey('stamp-US-CA')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('notebook-page-title')), findsOneWidget);
    expect(find.text(app.s.regionName('US-CA')), findsWidgets);
    expect(find.byKey(const ValueKey('notebook-hero-line')), findsOneWidget);
    expect(find.text(app.s.t('notebook.hero.${NotebookScreen.heroLineIndex('US-CA')}')), findsOneWidget);
    expect(find.byKey(const ValueKey('notebook-landmarks')), findsOneWidget);
    expect(find.byKey(const ValueKey('notebook-knowledge')), findsOneWidget);
  });
}

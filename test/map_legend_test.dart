import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_us/a11y.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/screens/clear_legend.dart';
import 'package:terrimap_us/screens/landmark_detail.dart';
import 'package:terrimap_us/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('地図の色: 未クリア(白)・クリアの3色・ロック(灰色)はすべて違う色', () {
    final colors = {
      A11yPalette.clearColor(null),
      for (final d in Difficulty.values) A11yPalette.clearColor(d),
      A11yPalette.lockedColor,
    };
    expect(colors.length, 5);
    // ロックの灰色は、未クリアの白より暗い
    expect(A11yPalette.lockedColor.computeLuminance(), lessThan(A11yPalette.clearColor(null).computeLuminance()));
  });

  test('文言: 地図の色の説明が全言語にある', () async {
    final app = await AppState.load();
    for (final lang in Strings.supported) {
      await app.setLang(lang);
      for (final k in ['legend.notCleared', 'legend.locked']) {
        expect(app.s.t(k), isNot(k), reason: '$lang $k');
      }
    }
  });

  testWidgets('凡例: 未クリアと難易度の色は常に、ロックの説明は購入前だけ出る', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    Future<void> show(bool locked) => t.pumpWidget(MaterialApp(home: Scaffold(body: Stack(children: [ClearLegend(app: app, showLocked: locked)]))));
    await show(true);
    expect(find.text('Not cleared'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    await show(false);
    expect(find.text('Locked'), findsNothing);
  });

  testWidgets('名所の詳細: そこから、州の解説ページに入れる', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    final lm = app.pack.facts!.landmarks.first;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => TextButton(onPressed: () => showLandmarkDetail(c, app, lm.id, art: const ArtSet()), child: const Text('go')))));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('landmark-guide')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-title')), findsOneWidget);
    expect(find.text(app.s.regionName(lm.regionId)), findsWidgets);
  });
}

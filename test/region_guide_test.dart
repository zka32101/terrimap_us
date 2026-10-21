import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/screens/region_guide_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('解説ページ: 州名・州都・紹介文・となりの州・名所が出る', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await t.pumpWidget(MaterialApp(home: RegionGuideScreen(app: app, regionId: 'US-CA')));
    await t.pump();
    expect(find.byKey(const ValueKey('guide-title')), findsOneWidget);
    expect(find.text(app.s.regionName('US-CA')), findsWidgets);
    expect(find.textContaining(app.s.capitalName('US-CA')), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-blurb')), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-neighbors')), findsOneWidget);
    expect(find.byType(ActionChip), findsWidgets); // 名所のチップ
  });

  testWidgets('解説ページ: 紹介文は表示言語になる(日本語)', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('ja');
    await t.pumpWidget(MaterialApp(home: RegionGuideScreen(app: app, regionId: 'US-DC')));
    await t.pump();
    expect(find.textContaining('首都'), findsWidgets);
  });

  testWidgets('隣のない州(ハワイ)でも開ける。となりの州の欄は出ない', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await t.pumpWidget(MaterialApp(home: RegionGuideScreen(app: app, regionId: 'US-HI')));
    await t.pump();
    expect(find.byKey(const ValueKey('guide-blurb')), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-neighbors')), findsNothing);
  });

  testWidgets('州の地図のシートと、クイズの答え合わせから、解説ページに入れる', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => TextButton(onPressed: () => openRegionGuide(c, app, 'US-TX'), child: const Text('go')))));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-title')), findsOneWidget);
    expect(find.text(app.s.regionName('US-TX')), findsWidgets);
  });
}

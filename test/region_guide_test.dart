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

  testWidgets('観光動画: 州と名所ごとに YouTube の検索ページを外で開く', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    final opened = <Uri>[];
    openExternalLink = (u) async => opened.add(u);
    addTearDown(() => openExternalLink = (u) async {});
    await t.pumpWidget(MaterialApp(home: RegionGuideScreen(app: app, regionId: 'US-CA')));
    await t.pump();
    final first = app.pack.facts!.inRegion('US-CA').first;
    await t.scrollUntilVisible(find.byKey(const ValueKey('guide-video-region')), 200);
    await t.tap(find.byKey(const ValueKey('guide-video-region')));
    await t.scrollUntilVisible(find.byKey(ValueKey('guide-video-${first.id}')), 200);
    await t.tap(find.byKey(ValueKey('guide-video-${first.id}')));
    expect(opened.length, 2);
    expect(opened.every((u) => u.host == 'www.youtube.com' && u.path == '/results'), isTrue);
    expect(opened[0].queryParameters['search_query'], '${app.s.regionName('US-CA')} travel guide');
    expect(opened[1].queryParameters['search_query'], '${first.nameIn('en')} travel guide');
    expect(opened.every((u) => u.scheme == 'https'), isTrue);
  });

  test('YouTube の検索URL: 空白や記号・日本語が正しくエンコードされる', () {
    final u = youtubeSearchUri('ノイシュヴァンシュタイン城 観光 & 旅');
    expect(Uri.parse(u.toString()).queryParameters['search_query'], 'ノイシュヴァンシュタイン城 観光 & 旅');
  });
}

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/looks.dart';
import 'package:terrimap_us/monetization.dart';
import 'package:terrimap_us/screens/settings_screen.dart';
import 'package:terrimap_us/screens/story_screen.dart';
import 'package:terrimap_us/screens/unlock_sheet.dart';

/// 本物のアセット一覧に、衣装の画像が同梱されたことにして読み込む。
Future<AppState> loadWithLooks(List<String> looks) async {
  final real = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
  return AppState.load(
    bundle: AssetBundleLike(
      rootBundle.loadString,
      listAssets: () async => [...real, for (final l in looks) 'assets/art/hero/us_hero@$l.png'],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('衣装の画像のパスから衣装idを取り出す。通常の画像・別の場所のファイルは対象外', () {
    expect(
      lookIdsFrom([
        'assets/art/hero/us_hero.png',
        'assets/art/hero/us_hero@winter.png',
        'assets/art/hero/us_hero@summer_hat.png',
        'assets/art/hero/us_hero@winter.png', // 重複
        'assets/art/bosses/x@y.png',
        'assets/art/hero/us_hero@Bad.png', // 大文字は対象外
      ]),
      ['summer_hat', 'winter'],
    );
    expect(heroAssetPath('us_hero'), 'assets/art/hero/us_hero.png');
    expect(heroAssetPath('us_hero', look: 'winter'), 'assets/art/hero/us_hero@winter.png');
    expect(lookLabel('summer_hat', (k) => k), 'Summer hat');
    expect(lookLabel('winter', (k) => k == 'look.winter' ? 'Winter coat' : k), 'Winter coat');
  });

  test('今の同梱物には衣装の画像がないので、見た目の設定も商品も出ない', () async {
    final app = await AppState.load();
    expect(app.lookIds, isEmpty);
    expect(app.activeLook, isNull);
  });

  test('使う見た目: 持っていて、画像が同梱されていて、選んだときだけ', () async {
    final app = await loadWithLooks(['winter']);
    expect(app.lookIds, ['winter']);
    await app.setLook('winter');
    expect(app.activeLook, isNull); // 持っていない
    app.syncEntitlement(const EntitlementState(extra: {looksEntitlementId}));
    expect(app.looksOwned, isTrue);
    expect(app.activeLook, 'winter');
    await app.setLook('ghost'); // 画像のない衣装は使えない
    expect(app.activeLook, isNull);
    await app.setLook(null);
    expect(app.activeLook, isNull);
    app.syncEntitlement(EntitlementState.free);
    expect(app.looksOwned, isFalse);
  });

  testWidgets('設定の「見た目」: 持っていなければ鍵つきで、押すと購入の案内。買うと選べる', (t) async {
    final app = await t.runAsync(() => loadWithLooks(['winter'])) as AppState;
    await app.setLang('en');
    final ent = Monetization.fakeEntitlement();
    await t.pumpWidget(ProviderScope(
      overrides: [entitlementServiceProvider.overrideWithValue(ent)],
      child: MaterialApp(home: SettingsScreen(app: app)),
    ));
    await t.pump();
    await t.scrollUntilVisible(find.byKey(const ValueKey('look-winter')), 300, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.byKey(const ValueKey('look-winter')));
    await t.pump();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('look-winter')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('offer-$looksProductId')), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-$unlockProductId')), findsNothing); // 見た目の案内に、買い切りは出さない
    await t.tap(find.byKey(const ValueKey('offer-$looksProductId')));
    await t.pumpAndSettle();
    app.syncEntitlement(ent.state);
    await t.pump();
    expect(ent.state.has(looksEntitlementId), isTrue);
    expect(ent.state.hasPremium, isFalse);

    await t.ensureVisible(find.byKey(const ValueKey('look-winter')));
    await t.tap(find.byKey(const ValueKey('look-winter')));
    await t.pump();
    expect(app.activeLook, 'winter');
  });

  testWidgets('解放シート: 画像がなければ見た目パックの商品は出ない。画像があり、未購入なら出す', (t) async {
    final plain = await t.runAsync(AppState.load) as AppState;
    await plain.setLang('en');
    final ent = Monetization.fakeEntitlement();
    Future<void> open(AppState a) async {
      await t.pumpWidget(ProviderScope(
        overrides: [entitlementServiceProvider.overrideWithValue(ent)],
        child: MaterialApp(
          home: Builder(builder: (c) => TextButton(onPressed: () => showUnlockSheet(c, a), child: const Text('open'))),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    await open(plain);
    expect(find.byKey(const ValueKey('offer-$looksProductId')), findsNothing);
    expect(find.byKey(const ValueKey('offer-$unlockProductId')), findsOneWidget);
    Navigator.of(t.element(find.byType(TextButton).first), rootNavigator: true).pop();
    await t.pumpAndSettle();

    final withLooks = await t.runAsync(() => loadWithLooks(['winter'])) as AppState;
    await withLooks.setLang('en');
    await open(withLooks);
    expect(find.byKey(const ValueKey('offer-$looksProductId')), findsOneWidget);
  });

  testWidgets('主人公のアイコン: 衣装の画像→通常の画像→頭文字の順に代わりを出す(どれも無ければ頭文字)', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    final hero = app.story!.hero!;
    await t.pumpWidget(MaterialApp(home: HeroAvatar(hero: hero, lang: 'en', look: 'winter')));
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
    }
    expect(find.text(hero.name.of('en')[0]), findsOneWidget);
  });

  test('ウィジェットの配色: 衣装なしは標準(0)、衣装ごとに1〜5で毎回同じ', () {
    expect(widgetSkinIndex(null), 0);
    for (final id in ['festival', 'winter', 'summer', 'night', 'x']) {
      final i = widgetSkinIndex(id);
      expect(i, inInclusiveRange(1, widgetSkinCount - 1));
      expect(widgetSkinIndex(id), i);
    }
  });
}

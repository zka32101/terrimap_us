import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/main.dart';
import 'package:terrimap_us/monetization.dart';

/// 広告SDKの代わり。バナーは目印のウィジェットを返す。
class FakeAdsBackend implements AdsBackend {
  @override
  Future<bool> initialize(AdConfig config) async => true;
  @override
  Future<void> preloadInterstitial() async {}
  @override
  bool get isInterstitialReady => false;
  @override
  Future<bool> showInterstitial() async => false;
  @override
  Future<bool> showRewarded() async => false;
  @override
  Widget buildBanner(BannerPlacement placement) => const SizedBox(key: Key('banner'), height: 50);
}

Future<Widget> app(AppState a, FakeEntitlementService ent) async {
  final ads = await AdGate.init(
    config: const AdConfig(
      unitIds: AdUnitIds(banner: 'b', interstitial: 'i', rewarded: 'r'),
    ),
    adsHidden: () => ent.state.adsHidden,
    backend: FakeAdsBackend(),
    prefs: await SharedPreferences.getInstance(),
    isRelease: false,
  );
  return ProviderScope(
    overrides: [
      entitlementServiceProvider.overrideWithValue(ent),
      optionalAdGateProvider.overrideWithValue(ads),
    ],
    child: TerrimapApp(app: a),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('無料は12州(51州の約24%)、購入すると全州', () async {
    final a = await AppState.load();
    final ids = a.pack.regions.map((r) => r.id).toList();
    expect(freeRegionIds.length / ids.length, closeTo(0.235, 0.02));
    expect(freeRegionIds.every(ids.contains), isTrue); // 存在しないidを無料にしていない
    expect(unlockedPool(ids, premium: false), freeRegionIds);
    expect(unlockedPool(ids, premium: true), ids.toSet());
    expect(isRegionUnlocked('US-RI', premium: false), isFalse);
    expect(isRegionUnlocked('US-CA', premium: false), isTrue);
  });

  test('無料の出題は解放済みの州だけ、選択肢の誤答には全州が使われる', () async {
    final a = await AppState.load();
    final pool = unlockedPool(a.pack.regions.map((r) => r.id), premium: false);
    final qs = QuizEngine(a.pack, seed: 9)
        .generate(count: 40, types: [QuestionType.nameFromMap], pool: pool);
    expect(qs.every((q) => pool.contains(q.targetId)), isTrue);
    expect(qs.expand((q) => q.choiceIds).toSet().length, greaterThan(pool.length));
  });

  testWidgets('無料: 広告と解放ボタンが出る → 購入すると両方消える', (t) async {
    final a = await t.runAsync(AppState.load) as AppState;
    await a.setLang('en');
    final ent = Monetization.fakeEntitlement();
    final widget = await t.runAsync(() => app(a, ent)) as Widget;
    await t.pumpWidget(widget);
    await t.pump();

    expect(find.byKey(const Key('banner')), findsOneWidget);
    expect(find.text('Unlock all 51 states'), findsOneWidget);

    await t.tap(find.text('Unlock all 51 states'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Unlock  —'));
    await t.pumpAndSettle();

    expect(ent.state.hasPremium, isTrue);
    expect(find.byKey(const Key('banner')), findsNothing);
    expect(find.text('Unlock all 51 states'), findsNothing);
  });

  testWidgets('広告だけ消す: 買うと広告は消えるが州は解放されない。その後は買い切りの商品だけ出る', (t) async {
    final a = await t.runAsync(AppState.load) as AppState;
    await a.setLang('en');
    final ent = Monetization.fakeEntitlement();
    final widget = await t.runAsync(() => app(a, ent)) as Widget;
    await t.pumpWidget(widget);
    await t.pump();
    expect(find.byKey(const Key('banner')), findsOneWidget);

    await t.tap(find.text('Unlock all 51 states'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('offer-$unlockProductId')), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-$removeAdsProductId')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('offer-$removeAdsProductId')));
    await t.pumpAndSettle();

    expect(ent.state.hasNoAds, isTrue);
    expect(ent.state.hasPremium, isFalse); // 州は解放されない
    expect(find.byKey(const Key('banner')), findsNothing);

    // 広告なしを持つ人には、買い切りの商品だけを出す
    await t.tap(find.text('Unlock all 51 states'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('offer-$unlockProductId')), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-$removeAdsProductId')), findsNothing);
  });

  testWidgets('購入済み(premium)で起動すると、広告も解放ボタンも出ない', (t) async {
    final a = await t.runAsync(AppState.load) as AppState;
    final ent = Monetization.fakeEntitlement()..setState(const EntitlementState(hasPremium: true));
    final widget = await t.runAsync(() => app(a, ent)) as Widget;
    await t.pumpWidget(widget);
    await t.pump();
    expect(find.byKey(const Key('banner')), findsNothing);
    expect(find.byIcon(Icons.lock_open), findsNothing);
  });
}

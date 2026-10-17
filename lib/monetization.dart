import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 無料で遊べる州(51の約24%=12州)。それ以外は買い切りで解放する。
/// 知名度が高く位置が分かりやすい大きな州・有名な州（アラスカ・ハワイは形が特徴的）。
const freeRegionIds = {
  'US-CA', 'US-TX', 'US-NY', 'US-FL', 'US-IL', 'US-WA',
  'US-CO', 'US-AZ', 'US-MA', 'US-GA', 'US-AK', 'US-HI',
};

/// 買い切りの商品ID。権利名は `premium`(全州解放＋広告なし)。ストア登録名と揃える。
const unlockProductId = 'unlock_all_states';

/// 解放済みか。無料の州か、買い切り購入済み(=広告なしも兼ねる premium)。
bool isRegionUnlocked(String regionId, {required bool premium}) =>
    premium || freeRegionIds.contains(regionId);

/// 出題の対象にする州の集合。
Set<String> unlockedPool(Iterable<String> allIds, {required bool premium}) =>
    {for (final id in allIds) if (isRegionUnlocked(id, premium: premium)) id};

/// 広告ゲート(キットの adGateProvider は必須のため、任意版をアプリ側に持つ)。広告の設定がない(開発・テスト)場合は null で、広告は一切出ない。
final optionalAdGateProvider = Provider<AdGate?>((ref) => null);

/// 起動時の課金・広告の組み立て。
///
/// 外部のキーは `--dart-define` で渡す(リポジトリに置かない):
/// - `RC_PUBLIC_KEY`: RevenueCat の公開SDKキー。空なら開発用のフェイク(購入は疑似)
/// - `ADMOB_BANNER` / `ADMOB_INTERSTITIAL` / `ADMOB_REWARDED`: 広告ユニットID。
///   3つとも空なら、リリースでは広告なし、デバッグではGoogleのテストIDで動く
class Monetization {
  final EntitlementService entitlement;
  final AdGate? ads;
  const Monetization(this.entitlement, this.ads);

  static const _rcKey = String.fromEnvironment('RC_PUBLIC_KEY');
  static const _banner = String.fromEnvironment('ADMOB_BANNER');
  static const _interstitial = String.fromEnvironment('ADMOB_INTERSTITIAL');
  static const _rewarded = String.fromEnvironment('ADMOB_REWARDED');

  /// 開発用: 購入ボタンで疑似的に全州解放できるフェイク。
  static FakeEntitlementService fakeEntitlement() => FakeEntitlementService(
        availableOffers: const [
          EntitlementOffer(
            id: 'unlock',
            productId: unlockProductId,
            title: 'Unlock all 51 states · no ads',
            priceString: '—',
          ),
        ],
        grantOnPurchase: {unlockProductId: const EntitlementState(hasPremium: true)},
      );

  static Future<Monetization> init() async {
    final EntitlementService entitlement = _rcKey.isEmpty
        ? fakeEntitlement()
        : await RevenueCatEntitlementService.init(publicSdkKey: _rcKey);

    AdGate? ads;
    final hasIds = _banner.isNotEmpty && _interstitial.isNotEmpty && _rewarded.isNotEmpty;
    if (hasIds || !kReleaseMode) {
      ads = await AdGate.init(
        config: AdConfig(
          unitIds: hasIds
              ? const AdUnitIds(banner: _banner, interstitial: _interstitial, rewarded: _rewarded)
              : const AdUnitIds(
                  // Google 公式のテスト広告ユニット。リリースでは使えない(AdGate が拒否)。
                  banner: 'ca-app-pub-3940256099942544/6300978111',
                  interstitial: 'ca-app-pub-3940256099942544/1033173712',
                  rewarded: 'ca-app-pub-3940256099942544/5224354917',
                ),
          childDirected: false, // 子ども向けにしない(COPPA/GDPR-K 回避)
        ),
        adsHidden: () => entitlement.state.adsHidden,
      );
    }
    return Monetization(entitlement, ads);
  }
}

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../looks.dart';
import '../monetization.dart';

/// 「全州を解放する」の案内。買い切りの購入と、購入の復元。
///
/// [looksOnly] が true なら、見た目パックだけを案内する(設定の「見た目」から)。
Future<void> showUnlockSheet(BuildContext context, AppState app, {bool looksOnly = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _UnlockSheet(app: app, looksOnly: looksOnly),
  );
}

class _UnlockSheet extends ConsumerWidget {
  final AppState app;
  final bool looksOnly;
  const _UnlockSheet({required this.app, this.looksOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = app.s;
    final service = ref.watch(entitlementServiceProvider);
    final ent = ref.watch(entitlementStateProvider).valueOrNull ?? service.state;
    final premium = ent.hasPremium;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t(looksOnly ? 'looksTitle' : 'unlockTitle'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(s.t(looksOnly ? 'looksBody' : 'unlockBody')),
            const SizedBox(height: 16),
            if (!looksOnly && premium)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(app.s.kit.purchasedPremium),
              ),
            FutureBuilder<List<EntitlementOffer>>(
              future: service.offers(),
              builder: (context, snap) => Column(children: [
                if (!looksOnly && !premium && ent.hasNoAds)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(app.s.kit.purchasedNoAds),
                  ),
                for (final offer in snap.data ?? const <EntitlementOffer>[])
                  if (_showOffer(offer, ent))
                    SizedBox(
                      width: double.infinity,
                      child: (isPremiumProduct(offer.productId) ? FilledButton.new : FilledButton.tonal)(
                        key: ValueKey('offer-${offer.productId}'),
                        onPressed: () async {
                          final outcome = await service.purchaseOffer(offer.id);
                          if (outcome == PurchaseOutcome.success && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Text('${s.t(_buttonKey(offer.productId))}  ${offer.priceString}'),
                      ),
                    ),
              ]),
            ),
            Row(children: [
              TextButton(
                onPressed: () => service.restore(),
                child: Text(s.t('restore')),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('notNow'))),
            ]),
          ],
        ),
      ),
    );
  }

  static String _buttonKey(String productId) => isPremiumProduct(productId)
      ? 'unlockButton'
      : isLooksProduct(productId)
          ? 'looksButton'
          : 'removeAdsButton';

  /// 出す商品。見た目パックは、衣装の画像が同梱されていて、まだ持っていないときだけ。
  /// 買い切り・広告削除は、見た目パックの案内では出さない。持っている権利の商品も出さない
  /// (広告削除は、広告なしや買い切りを持つ人には不要)。
  bool _showOffer(EntitlementOffer o, EntitlementState ent) {
    if (isLooksProduct(o.productId)) return app.lookIds.isNotEmpty && !ent.has(looksEntitlementId);
    if (looksOnly || ent.hasPremium) return false;
    return !ent.hasNoAds || isPremiumProduct(o.productId);
  }
}

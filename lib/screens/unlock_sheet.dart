import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../monetization.dart';

/// 「全州を解放する」の案内。買い切りの購入と、購入の復元。
Future<void> showUnlockSheet(BuildContext context, AppState app) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _UnlockSheet(app: app),
  );
}

class _UnlockSheet extends ConsumerWidget {
  final AppState app;
  const _UnlockSheet({required this.app});

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
            Text(s.t('unlockTitle'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(s.t('unlockBody')),
            const SizedBox(height: 16),
            if (premium)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(app.s.kit.purchasedPremium),
              )
            else
              FutureBuilder<List<EntitlementOffer>>(
                future: service.offers(),
                builder: (context, snap) => Column(children: [
                  if (ent.hasNoAds)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(app.s.kit.purchasedNoAds),
                    ),
                  // 広告だけの単体商品は、広告なしを持つ人には出さない(買い切りの商品だけ出す)
                  for (final offer in snap.data ?? const <EntitlementOffer>[])
                    if (!ent.hasNoAds || isPremiumProduct(offer.productId))
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
                          child: Text(
                              '${s.t(isPremiumProduct(offer.productId) ? 'unlockButton' : 'removeAdsButton')}  ${offer.priceString}'),
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
}

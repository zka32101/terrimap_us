/// 見た目パック(買い切り・非消耗)。勝敗にも性能にも関わらない、主人公の衣装などの見た目だけ。
///
/// 衣装の画像は `assets/art/hero/<主人公id>@<衣装id>.png`(512x512 の透過PNG)。画像が同梱された衣装だけが
/// 一覧に出る(画像がなければ何も出ず、商品も出さない)。
library;

/// RevenueCat の権利名(Entitlement ID)。キットの `EntitlementState.extra` に入る。
const looksEntitlementId = 'looks';

/// ストアの商品ID(非消耗型)。
const looksProductId = 'looks_pack';

/// 見た目パックの商品か。
bool isLooksProduct(String productId) => productId == looksProductId;

final _outfitAsset = RegExp(r'^assets/art/hero/[^@/]+@([a-z0-9_]+)\.png$');

/// アセットの一覧から、同梱された衣装のid(重複なし・並びは名前順)を取り出す。
List<String> lookIdsFrom(Iterable<String> assetKeys) {
  final ids = <String>{};
  for (final k in assetKeys) {
    final m = _outfitAsset.firstMatch(k);
    if (m != null) ids.add(m.group(1)!);
  }
  return ids.toList()..sort();
}

/// 主人公のアイコン画像のパス。[look] が null なら通常の見た目。
String heroAssetPath(String heroId, {String? look}) =>
    look == null ? 'assets/art/hero/$heroId.png' : 'assets/art/hero/$heroId@$look.png';

/// 衣装の表示名。文言(`look.<id>`)がなければ、idの先頭を大文字にして出す。
String lookLabel(String id, String Function(String key) t) {
  final v = t('look.$id');
  if (v != 'look.$id') return v;
  return id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1).replaceAll('_', ' ')}';
}

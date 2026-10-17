
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/pack/region_pack.dart';
import 'package:terrimap_core/progress/region_progress.dart';

import 'strings.dart';

const _progressKey = 'progress_v1';
const _langKey = 'lang';

/// アプリ全体の状態: pack・進捗(端末に保存)・表示言語。
class AppState extends ChangeNotifier {
  final RegionPack pack;
  final JsonProgressStore store;
  final SharedPreferences prefs;
  String _lang;
  RegionProgress progress;

  AppState._(this.pack, this.store, this.prefs, this._lang, this.progress);

  static Future<AppState> load({SharedPreferences? prefs, AssetBundleLike? bundle}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    Future<String> asset(String name) =>
        (bundle?.loadString ?? rootBundle.loadString)('packs/us/$name');
    final pack = RegionPack.parse(
      packJson: await asset('pack.json'),
      regionsJson: await asset('regions.json'),
      geoJson: await asset('geo.geojson'),
      stringsJsonByLang: {for (final l in Strings.supported) l: await asset('strings/$l.json')},
    );
    final saved = p.getString(_progressKey);
    final store = saved == null ? JsonProgressStore() : JsonProgressStore.fromJson(saved);
    final lang = p.getString(_langKey) ?? 'en';
    final progress = await RegionProgress.load(store, pack.packId, pack.regions.map((r) => r.id));
    return AppState._(pack, store, p, lang, progress);
  }

  String get lang => _lang;
  Strings get s => Strings(_lang, pack);

  Future<void> setLang(String l) async {
    _lang = l;
    await prefs.setString(_langKey, l);
    notifyListeners();
  }

  /// 1問の結果を進捗に反映して保存する。
  Future<void> record(String regionId, {required bool correct}) async {
    if (correct) {
      await store.markMastered(pack.packId, regionId);
    } else {
      await store.recordMiss(pack.packId, regionId);
    }
    await prefs.setString(_progressKey, store.toJson());
    progress = await RegionProgress.load(store, pack.packId, pack.regions.map((r) => r.id));
    notifyListeners();
  }
}

/// テストでアセットを差し替えるための薄い型。
class AssetBundleLike {
  final Future<String> Function(String key) loadString;
  const AssetBundleLike(this.loadString);
}


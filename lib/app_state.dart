
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:terrimap_core/battle/battle_progress.dart';
import 'package:terrimap_core/battle/replay.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/i18n/languages.dart';
import 'package:terrimap_core/i18n/ui_strings.dart';
import 'package:terrimap_core/pack/region_pack.dart';
import 'package:terrimap_core/progress/region_progress.dart';

import 'strings.dart';

const _progressKey = 'progress_v1';
const _langKey = 'lang';
const _assistKey = 'quiz_assist';
const _battleKey = 'battle_progress_v1';
const _dailyKey = 'daily_battle_v1';

/// アプリ全体の状態: pack・進捗(端末に保存)・表示言語。
class AppState extends ChangeNotifier {
  final RegionPack pack;
  final JsonProgressStore store;
  final SharedPreferences prefs;
  final Map<String, String> _battleJson; // 言語コード→画面の文言(JSON)
  String _lang;
  bool _quizAssist;
  RegionProgress progress;
  final BattleProgress battle; // バトルのクリア記録（地方決戦・エクストラの解放に使う）

  AppState._(this.pack, this.store, this.prefs, this._lang, this.progress, this._battleJson, this._quizAssist, this.battle);

  static Future<AppState> load({SharedPreferences? prefs, AssetBundleLike? bundle}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    Future<String> asset(String name) =>
        (bundle?.loadString ?? rootBundle.loadString)('packs/us/$name');
    final pack = RegionPack.parse(
      packJson: await asset('pack.json'),
      regionsJson: await asset('regions.json'),
      geoJson: await asset('geo.geojson'),
      stringsJsonByLang: {for (final l in Strings.supported) l: await asset('strings/$l.json')},
      profileJson: await asset('profile.json'),
    );
    // 画面の文言（コアに同梱。言語ごとのファイルがあるものだけ読む）
    final battle = <String, String>{};
    final manifest = bundle?.listAssets != null ? await bundle!.listAssets!() : (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
    for (final key in manifest) {
      final m = RegExp(r'^packages/terrimap_core/i18n/battle\.(\w+)\.json$').firstMatch(key);
      if (m != null) battle[m.group(1)!] = await (bundle?.loadString ?? rootBundle.loadString)(key);
    }
    final saved = p.getString(_progressKey);
    final store = saved == null ? JsonProgressStore() : JsonProgressStore.fromJson(saved);
    final deviceLang = PlatformDispatcher.instance.locale.languageCode;
    final lang = p.getString(_langKey) ?? resolveLanguage(deviceLang);
    final progress = await RegionProgress.load(store, pack.packId, pack.regions.map((r) => r.id));
    return AppState._(pack, store, p, lang, progress, battle, p.getBool(_assistKey) ?? true, BattleProgress.fromJsonString(p.getString(_battleKey)));
  }

  String get lang => _lang;
  Strings get s => Strings(_lang, pack);

  /// バトル画面の文言（その言語になければ英語）。
  UiStrings get ui => UiStrings.parse(_battleJson, lang: _lang);

  /// バトル中のクイズ連動（設定）。
  bool get quizAssist => _quizAssist;

  Future<void> setQuizAssist(bool v) async {
    _quizAssist = v;
    await prefs.setBool(_assistKey, v);
    notifyListeners();
  }

  Future<void> setLang(String l) async {
    _lang = l;
    await prefs.setString(_langKey, l);
    notifyListeners();
  }

  /// 今日の日付(UTC の yyyy-MM-dd)。テストで差し替える。
  String Function() today = () => DateTime.now().toUtc().toIso8601String().substring(0, 10);

  /// 今日のバトルの結果(日付→リプレイ)。直近の数日ぶんだけ残す。
  Map<String, Replay> get _daily {
    final raw = prefs.getString(_dailyKey);
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          if (Replay.tryParse(e.value as String) != null) e.key: Replay.tryParse(e.value as String)!,
      };
    } catch (_) {
      return {};
    }
  }

  Replay? dailyReplay(String date) => _daily[date];

  Future<void> saveDaily(String date, Replay r) async {
    final all = _daily..[date] = r;
    final keys = all.keys.toList()..sort();
    for (final k in keys.take((keys.length - 7).clamp(0, keys.length))) {
      all.remove(k);
    }
    await prefs.setString(_dailyKey, jsonEncode({for (final e in all.entries) e.key: e.value.toJsonString()}));
    notifyListeners();
  }

  /// バトルのクリアを記録して保存する。
  Future<void> recordBattleClear(StageKind kind, String id, Difficulty difficulty) async {
    battle.recordClear(kind, id, difficulty);
    await prefs.setString(_battleKey, battle.toJsonString());
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
  final Future<List<String>> Function()? listAssets; // 画面の文言を探すとき（省略すると本物のアセット一覧）
  const AssetBundleLike(this.loadString, {this.listAssets});
}


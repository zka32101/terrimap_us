
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:app_common_kit/app_common_kit.dart' show ReviewPromptService;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:terrimap_core/battle/achievements.dart';
import 'package:terrimap_core/battle/battle_progress.dart';
import 'package:terrimap_core/battle/collection.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_core/battle/review.dart';
import 'package:terrimap_core/battle/weekly_battle.dart';
import 'package:terrimap_core/daily/daily_streak.dart';
import 'package:terrimap_core/battle/replay.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/battle/invite.dart';
import 'package:terrimap_core/i18n/languages.dart';
import 'package:terrimap_core/i18n/ui_strings.dart';
import 'package:terrimap_core/pack/region_pack.dart';
import 'package:terrimap_core/progress/region_progress.dart';

import 'strings.dart';

const _progressKey = 'progress_v1';
const _langKey = 'lang';
const _assistKey = 'quiz_assist';
const _tutorialKey = 'tutorial_done_v1';
const _battleKey = 'battle_progress_v1';
const _dailyKey = 'daily_battle_v1';
const _streakKey = 'daily_streak_v1';
const _weeklyKey = 'weekly_battle_v1';
const _seenCardsKey = 'collection_seen_v1';
const _seenAchKey = 'achievements_seen_v1';

/// アプリ全体の状態: pack・進捗(端末に保存)・表示言語。
class AppState extends ChangeNotifier {
  final RegionPack pack;
  JsonProgressStore store;
  final SharedPreferences prefs;
  final Map<String, String> _battleJson; // 言語コード→画面の文言(JSON)
  String _lang;
  bool _quizAssist;
  RegionProgress progress;

  /// レビューを頼むタイミングの制御。端末で動かすときだけ main が入れる（テストでは null で、何もしない）。
  ReviewPromptService? review;
  BattleProgress battle; // バトルのクリア記録（地方決戦・エクストラの解放に使う）

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
      factsJson: await asset('facts.json'),
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

  /// 端末のデータを消したあとなど、保存済みの値から状態を読み直す。
  Future<void> reloadFromPrefs() async {
    final saved = prefs.getString(_progressKey);
    store = saved == null ? JsonProgressStore() : JsonProgressStore.fromJson(saved);
    battle = BattleProgress.fromJsonString(prefs.getString(_battleKey));
    _lang = prefs.getString(_langKey) ?? resolveLanguage(PlatformDispatcher.instance.locale.languageCode);
    _quizAssist = prefs.getBool(_assistKey) ?? true;
    progress = await RegionProgress.load(store, pack.packId, pack.regions.map((r) => r.id));
    await review?.load(); // データ削除のあとは、レビュー依頼の記録も初期に戻る
    notifyListeners();
  }

  String get lang => _lang;
  Strings get s => Strings(_lang, pack);

  /// 名所の名前（その言語になければ英語）。名所のデータがなければ空。
  String landmarkName(String? id) {
    final l = pack.facts?.landmarks.where((x) => x.id == id);
    return l == null || l.isEmpty ? '' : l.first.nameIn(_lang);
  }

  ArtSet? _art;

  /// 画像（`assets/art/`。今は図鑑カードの名所画像だけ）。画像が無いものはアイコンで出る。読み込みは初回だけ。
  Future<ArtSet> art() async => _art ??= await ArtSet.load(rootBundle);

  /// バトル画面の文言（その言語になければ英語）。
  UiStrings get ui => UiStrings.parse(_battleJson, lang: _lang);

  /// バトル中のクイズ連動（設定）。
  bool get quizAssist => _quizAssist;

  /// 初回バトルの案内（チュートリアル）を終えたか。設定の「もう一度見る」で戻せる。
  bool get tutorialDone => prefs.getBool(_tutorialKey) ?? false;

  Future<void> setTutorialDone(bool v) async {
    await prefs.setBool(_tutorialKey, v);
    notifyListeners();
  }

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

  /// 毎日のバトルの連続記録（終えた日を数える。勝敗は問わない）。
  DailyStreak get streak {
    final raw = prefs.getString(_streakKey);
    if (raw == null) return const DailyStreak();
    try {
      return DailyStreak.fromJson(raw);
    } catch (_) {
      return const DailyStreak();
    }
  }

  /// 名所のコレクション（州をクリアすると、その州の名所が集まる）。
  Collection get collection => Collection(pack.facts, battle);

  /// 見たことのあるカード（NEW の表示に使う）。
  Set<String> get seenCards => (prefs.getStringList(_seenCardsKey) ?? const <String>[]).toSet();

  /// 今のカードを、すべて見たことにする（コレクション画面を開いたとき）。
  Future<void> markCardsSeen() async {
    await prefs.setStringList(_seenCardsKey, collection.unlockedIds.toList()..sort());
    notifyListeners();
  }

  /// 名所の名前（コレクションの表示用）。
  int get newCardCount => collection.unlockedIds.difference(seenCards).length;

  /// 実績（毎回データから計算する。保存するのは「見たことのある実績」だけ）。
  Achievements get achievements => Achievements(
        regionIds: [for (final r in pack.regions) r.id],
        progress: battle,
        collection: collection,
        bestStreak: streak.best,
        regions: progress,
      );

  Set<String> get seenAchievements => (prefs.getStringList(_seenAchKey) ?? const <String>[]).toSet();

  Future<void> markAchievementsSeen() async {
    await prefs.setStringList(_seenAchKey, achievements.unlockedIds.toList()..sort());
    notifyListeners();
  }

  int get newAchievementCount => achievements.unlockedIds.difference(seenAchievements).length;

  /// 招待コードのステージの名前（州・地方・エクストラ）。
  String inviteStageName(Invite inv) {
    final profile = pack.profile;
    switch (inv.kind) {
      case StageKind.normal:
        return s.regionName(inv.stageId);
      case StageKind.regional:
        return profile?.groups[inv.stageId]?.nameIn(lang) ?? inv.stageId;
      case StageKind.extra:
        return profile?.extras.where((e) => e.id == inv.stageId).firstOrNull?.titleIn(lang) ?? inv.stageId;
    }
  }

  /// 友だちに送る招待の文面（一文・自分の結果・コード）。
  String inviteText(Invite inv) => inv.shareText(
        headline: ui.t('invite.headline', {'app': s.t('appTitle'), 'stage': inviteStageName(inv), 'difficulty': ui.t('difficulty.${inv.difficulty.name}')}),
        result: inv.hasResult ? ui.t('invite.result', {'mark': inv.won! ? '✅' : '❌', 'hp': inv.baseHp!}) : '',
      );

  /// 復習: 間違えた州がバトルのクイズで出やすくなる重み。
  Map<String, double> get reviewWeights => battleReviewWeights(progress);

  /// 今週のチャレンジ。無料の間は、無料の州だけから選ぶ。
  WeeklyBattle weekly({required bool premium, Set<String> freeIds = const {}}) =>
      WeeklyBattle.forDate(pack, today(), allowedIds: premium ? null : freeIds);

  /// 今週の挑戦の結果（今週のものだけ。まだなら null）。1週に1回だけ挑戦できる。
  WeeklyRecord? get weeklyRecord {
    final r = WeeklyRecord.fromJson(prefs.getString(_weeklyKey));
    return r != null && r.doneIn(WeeklyBattle.weekOf(today())) ? r : null;
  }

  Future<void> saveWeekly(String week, bool won, int baseHp) async {
    await prefs.setString(_weeklyKey, WeeklyRecord(week, won, baseHp).toJson());
    notifyListeners();
  }

  /// 今週のチャレンジを友だちに送る文面（結果があれば添える）。
  String weeklyText(WeeklyBattle w, {WeeklyRecord? record}) {
    final inv = w.invite(pack.packId, won: record?.won, baseHp: record?.baseHp);
    return inv.shareText(
      headline: ui.t('weekly.headline', {'app': s.t('appTitle'), 'stage': inviteStageName(inv), 'difficulty': ui.t('difficulty.${w.difficulty.name}')}),
      result: record == null ? '' : ui.t('invite.result', {'mark': record.won ? '✅' : '❌', 'hp': record.baseHp}),
    );
  }

  Future<void> saveDaily(String date, Replay r) async {
    final all = _daily..[date] = r;
    final keys = all.keys.toList()..sort();
    for (final k in keys.take((keys.length - 7).clamp(0, keys.length))) {
      all.remove(k);
    }
    await prefs.setString(_dailyKey, jsonEncode({for (final e in all.entries) e.key: e.value.toJsonString()}));
    await prefs.setString(_streakKey, streak.record(date).toJson());
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


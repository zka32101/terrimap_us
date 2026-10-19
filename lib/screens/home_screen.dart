import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terrimap_core/battle/review.dart';
import 'package:terrimap_core/daily/daily_challenge.dart';
import 'package:terrimap_core/map/region_map_view.dart';
import 'package:terrimap_core/progress/region_progress.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';

import '../app_state.dart';
import '../monetization.dart';
import 'daily_landmark_card.dart';
import 'landmark_quiz_summary.dart';
import 'quiz_screen.dart';
import 'stage_picker_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'unlock_sheet.dart';

class HomeScreen extends ConsumerWidget {
  final AppState app;
  const HomeScreen({super.key, required this.app});

  /// 無料の間は、解放済みの州だけを出題する(選択肢の誤答には全州が使われる)。
  /// [review] のときは、間違えて未習得の州だけを出題する（復習）。
  Future<void> _startQuiz(BuildContext context, WidgetRef ref, {required bool premium, bool review = false, bool landmarks = false}) async {
    app.sfx('tap');
    final unlocked = unlockedPool(app.pack.regions.map((r) => r.id), premium: premium);
    final base = review ? reviewPool(app.progress, allowed: unlocked) : unlocked;
    final pool = landmarks ? {for (final id in base) if (app.landmarkRegionIds.contains(id)) id} : base;
    if (pool.isEmpty) return;
    final qs = QuizEngine(app.pack, seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF)
        .generate(count: 10, types: landmarks ? const [QuestionType.landmarkOf] : QuestionType.values, pool: pool, weights: review ? null : app.quizWeights);
    final results = await Navigator.of(context)
        .push<List<bool>>(MaterialPageRoute(builder: (_) => QuizScreen(app: app, questions: qs)));
    if (results != null && context.mounted) {
      await ref.read(optionalAdGateProvider)?.maybeShowInterstitial(InterstitialTrigger.sessionEnd);
      if (context.mounted) _showResult(context, results, null, questions: landmarks ? qs : null);
    }
  }

  /// デイリーは全員が同じ問題(日付固定)なので、無料でも全州から出す。
  Future<void> _startDaily(BuildContext context, WidgetRef ref) async {
    app.sfx('tap');
    final date = _utcDate();
    final qs = DailyChallenge.forDate(app.pack, date);
    final results = await Navigator.of(context)
        .push<List<bool>>(MaterialPageRoute(builder: (_) => QuizScreen(app: app, questions: qs)));
    if (results != null && context.mounted) {
      await ref.read(optionalAdGateProvider)?.maybeShowInterstitial(InterstitialTrigger.sessionEnd);
      if (context.mounted) {
        _showResult(context, results, DailyChallenge.shareText(app.s.t('appTitle'), date, results));
      }
    }
  }

  static String _utcDate() {
    final d = DateTime.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  void _showResult(BuildContext context, List<bool> results, String? share, {List<Question>? questions}) {
    final s = app.s;
    final score = results.where((e) => e).length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('result')),
        content: questions != null
            ? SingleChildScrollView(child: LandmarkQuizSummary(app: app, results: results, questions: questions))
            : Text('$score / ${results.length}\n${results.map((e) => e ? '🟩' : '🟥').join()}'),
        actions: [
          if (share != null)
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: share));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(s.t('copied'))));
                }
              },
              child: Text(s.t('share')),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('home'))),
        ],
      ),
    );
  }

  static const _lockedColor = Color(0xFFB0BEC5);

  String _titleLabel(RegionTitle t) => app.s.t(t.name);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(entitlementServiceProvider);
    final premium = ref.watch(entitlementStateProvider).valueOrNull?.hasPremium ??
        service.state.hasPremium;
    final ads = ref.watch(optionalAdGateProvider);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.s;
        final p = app.progress;
        final reviewCount = reviewPool(p, allowed: unlockedPool(app.pack.regions.map((r) => r.id), premium: premium)).length;
        return Scaffold(
          appBar: AppBar(
            title: Text(s.t('appTitle')),
            actions: [
              IconButton(
                key: const ValueKey('stats'),
                tooltip: s.t('stats'),
                icon: const Icon(Icons.bar_chart),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => StatsScreen(app: app))),
              ),
              IconButton(
                tooltip: s.t('settings'),
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => SettingsScreen(app: app))),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  Chip(label: Text(_titleLabel(p.title))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(value: p.ratio, minHeight: 8),
                  ),
                  const SizedBox(width: 12),
                  Text('${p.masteredCount} / ${p.total}'),
                ]),
              ),
              Expanded(
                child: RegionMapView(
                  pack: app.pack,
                  showZoomControls: true,
                  onTap: (id) {
                    if (!isRegionUnlocked(id, premium: premium)) showUnlockSheet(context, app);
                  },
                  colorOf: (id) => isRegionUnlocked(id, premium: premium)
                      ? defaultRegionColor(p.stateOf(id))
                      : _lockedColor,
                ),
              ),
              DailyLandmarkCard(app: app),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('battle'),
                    icon: const Icon(Icons.shield),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => StagePickerScreen(app: app))),
                    label: Text(s.t('battle')),
                  ),
                ),
              ),
              if (app.landmarkRegionIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('landmark-quiz'),
                      icon: const Icon(Icons.photo_outlined),
                      onPressed: () => _startQuiz(context, ref, premium: premium, landmarks: true),
                      label: Text(s.t('landmarkQuiz')),
                    ),
                  ),
                ),
              if (reviewCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('review'),
                      icon: const Icon(Icons.replay),
                      onPressed: () => _startQuiz(context, ref, premium: premium, review: true),
                      label: Text('${s.t('review')} ($reviewCount)'),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: FilledButton(
                        onPressed: () => _startQuiz(context, ref, premium: premium),
                        child: Text(s.t('quiz'))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                        onPressed: () => _startDaily(context, ref), child: Text(s.t('daily'))),
                  ),
                ]),
              ),
              if (!premium)
                TextButton.icon(
                  onPressed: () => showUnlockSheet(context, app),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: Text(s.t('unlockTitle')),
                ),
              if (ads != null) ads.banner(BannerPlacement.home),
            ]),
          ),
        );
      },
    );
  }
}

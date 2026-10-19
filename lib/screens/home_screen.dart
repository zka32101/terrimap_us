import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terrimap_core/battle/review.dart';
import 'package:terrimap_core/daily/daily_challenge.dart';
import 'package:terrimap_core/daily/quiz_invite.dart';
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

  /// 友だちへの挑戦状。[inv] があればそのコードの問題、なければ新しい問題を作る。
  Future<void> _startInvite(BuildContext context, WidgetRef ref, [QuizInvite? inv]) async {
    app.sfx('tap');
    final base = inv ?? QuizInvite(packId: app.pack.packId, seed: (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF) | 1);
    final qs = base.questions(app.pack);
    final results = await Navigator.of(context)
        .push<List<bool>>(MaterialPageRoute(builder: (_) => QuizScreen(app: app, questions: qs)));
    if (results != null && context.mounted) {
      await ref.read(optionalAdGateProvider)?.maybeShowInterstitial(InterstitialTrigger.sessionEnd);
      if (!context.mounted) return;
      final ui = app.ui;
      final score = results.where((e) => e).length;
      final mine = base.withScore(score);
      final share = '${app.s.t('appTitle')}\n${mine.shareText(headline: ui.t('qinvite.headline'), result: ui.t('qinvite.result', {'n': score, 'total': results.length}))}';
      final extra = inv?.score == null ? null : ui.t('qinvite.compare', {'a': inv!.score!, 'b': score, 'n': results.length});
      _showResult(context, results, share, extra: extra);
    }
  }

  Future<void> _enterInvite(BuildContext context, WidgetRef ref) async {
    final ui = app.ui;
    final ctl = TextEditingController();
    final inv = await showDialog<QuizInvite>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        final parsed = QuizInvite.parse(ctl.text);
        final ok = parsed != null && parsed.isValidFor(app.pack);
        return AlertDialog(
          title: Text(ui.t('qinvite.enter')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const ValueKey('qinvite-field'),
              controller: ctl,
              decoration: InputDecoration(hintText: ui.t('qinvite.hint')),
              onChanged: (_) => setState(() {}),
            ),
            if (ctl.text.trim().isNotEmpty && !ok)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(ui.t('qinvite.invalid'), key: const ValueKey('qinvite-invalid'))),
          ]),
          actions: [
            TextButton(
              key: const ValueKey('qinvite-start'),
              onPressed: ok ? () => Navigator.pop(ctx, parsed) : null,
              child: Text(ui.t('qinvite.start')),
            ),
          ],
        );
      }),
    );
    if (inv != null && context.mounted) await _startInvite(context, ref, inv);
  }

  static String _utcDate() {
    final d = DateTime.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  void _showResult(BuildContext context, List<bool> results, String? share, {List<Question>? questions, String? extra}) {
    final s = app.s;
    final score = results.where((e) => e).length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('result')),
        content: questions != null
            ? SingleChildScrollView(child: LandmarkQuizSummary(app: app, results: results, questions: questions))
            : Text('$score / ${results.length}\n${results.map((e) => e ? '🟩' : '🟥').join()}${extra == null ? '' : '\n$extra'}'),
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
              PopupMenuButton<String>(
                key: const ValueKey('qinvite-menu'),
                tooltip: app.ui.t('qinvite.send'),
                icon: const Icon(Icons.people_outline),
                onSelected: (v) => v == 'send' ? _startInvite(context, ref) : _enterInvite(context, ref),
                itemBuilder: (_) => [
                  PopupMenuItem(key: const ValueKey('qinvite-send'), value: 'send', child: Text(app.ui.t('qinvite.send'))),
                  PopupMenuItem(key: const ValueKey('qinvite-enter'), value: 'enter', child: Text(app.ui.t('qinvite.enter'))),
                ],
              ),
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
                // 文字を大きくしても収まるように、称号と数は折り返せるようにする
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Chip(label: Text(_titleLabel(p.title))),
                    Text('${p.masteredCount} / ${p.total}'),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width - 32,
                      child: LinearProgressIndicator(value: p.ratio, minHeight: 8),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RegionMapView(
                  pack: app.pack,
                  showZoomControls: true,
                  onTap: (id) {
                    if (!isRegionUnlocked(id, premium: premium)) showUnlockSheet(context, app);
                  },
                  colorOf: (id) => isRegionUnlocked(id, premium: premium)
                      ? app.palette.region(p.stateOf(id))
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

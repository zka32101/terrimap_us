import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// シリーズ共通のアクセント(橙)。国ごとの色はベース色として渡す。
const resultOrange = Color(0xFFF4A300);

/// この国のベース色(アイコンの背景と同じ藍)。
const resultBase = Color(0xFF2B2D77);

/// 星の数。負けは0、勝ちは1、拠点の耐久が半分以上で2、満タンで3。
int resultStars({required bool won, required int baseHp, required int maxHp}) {
  if (!won) return 0;
  if (baseHp >= maxHp) return 3;
  if (baseHp * 2 >= maxHp) return 2;
  return 1;
}

/// バトルの結果。勝つと紙吹雪と星が出る(動きを減らす設定のときは、動かさずに出す)。
/// 背景は州の背景画像をぼかして敷き、国のベース色で包む。
class ResultDialog extends StatefulWidget {
  final bool won;
  final String title;
  final int stars;
  final int score;
  final String Function(int score) scoreText;
  final String subtitle; // 波の数など
  final String? extra; // 自己ベスト・新しい名所カードなど
  final ui.Image? backdrop;
  final List<Widget> secondary; // 共有・リプレイなどの文字ボタン
  final List<Widget> primary; // もう一度・戻る

  const ResultDialog({
    super.key,
    required this.won,
    required this.title,
    required this.stars,
    required this.score,
    required this.scoreText,
    required this.subtitle,
    this.extra,
    this.backdrop,
    this.secondary = const [],
    this.primary = const [],
  });

  @override
  State<ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<ResultDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) _c.value = 1;
    final won = widget.won;
    final top = won ? resultBase : const Color(0xFF3B2A4A);
    final bottom = won ? const Color(0xFF14153C) : const Color(0xFF16161F);
    final accent = won ? resultOrange : const Color(0xFFB39DDB);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom])),
              child: widget.backdrop == null
                  ? null
                  : Opacity(
                      opacity: 0.2,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: RawImage(image: widget.backdrop, fit: BoxFit.cover),
                      ),
                    ),
            ),
          ),
          if (won && !reduce) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_c, accent)))),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Title(text: widget.title, accent: accent, controller: _c),
              const SizedBox(height: 12),
              if (won) _Stars(count: widget.stars, controller: _c, accent: accent),
              if (won) const SizedBox(height: 12),
              Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 6),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: widget.score),
                duration: reduce ? Duration.zero : const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  widget.scoreText(v),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: accent, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
              if (widget.extra != null && widget.extra!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                  child: Text(widget.extra!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.secondary.isNotEmpty)
                Theme(
                  data: Theme.of(context).copyWith(textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.white, visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 13)))),
                  child: Wrap(alignment: WrapAlignment.center, spacing: 2, runSpacing: 0, children: widget.secondary),
                ),
              if (widget.primary.isNotEmpty) const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF14153C),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: widget.primary),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final Color accent;
  final AnimationController controller;
  const _Title({required this.text, required this.accent, required this.controller});

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: controller, curve: const Interval(0, 0.22, curve: Curves.elasticOut));
    return ScaleTransition(
      scale: Tween<double>(begin: 0.4, end: 1).animate(a),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(
          color: accent,
          fontSize: text.length > 10 ? 30 : 42,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [
            Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 18),
            const Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 3)),
          ],
        ),
      ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int count;
  final AnimationController controller;
  final Color accent;
  const _Stars({required this.count, required this.controller, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < 3; i++)
        Builder(builder: (context) {
          final start = 0.18 + i * 0.12;
          final a = CurvedAnimation(parent: controller, curve: Interval(start, start + 0.2, curve: Curves.elasticOut));
          final on = i < count;
          return ScaleTransition(
            scale: Tween<double>(begin: 0, end: 1).animate(a),
            child: Padding(
              padding: EdgeInsets.only(left: 4, right: 4, top: i == 1 ? 0 : 10),
              child: Icon(
                on ? Icons.star_rounded : Icons.star_outline_rounded,
                size: i == 1 ? 64 : 52,
                color: on ? accent : Colors.white38,
                shadows: on ? [Shadow(color: accent.withValues(alpha: 0.7), blurRadius: 14)] : null,
              ),
            ),
          );
        }),
    ]);
  }
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> t;
  final Color accent;
  _ConfettiPainter(this.t, this.accent) : super(repaint: t);

  static const _n = 56;
  static final _rand = math.Random(7);
  static final List<List<double>> _p = [for (var i = 0; i < _n; i++) [_rand.nextDouble(), 0.55 + _rand.nextDouble() * 0.9, _rand.nextDouble() * 6.28, 5 + _rand.nextDouble() * 7, _rand.nextDouble() * 6.28]];

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [accent, Colors.white, const Color(0xFFFFD54F), const Color(0xFF80DEEA), const Color(0xFFF48FB1)];
    final k = t.value;
    for (var i = 0; i < _n; i++) {
      final p = _p[i];
      final fall = (k * p[1] * 1.5 - 0.1 - (i % 7) * 0.03);
      if (fall < 0 || fall > 1.1) continue;
      final x = p[0] * size.width + math.sin(k * 9 + p[2]) * 22;
      final y = fall * (size.height + 40) - 20;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p[4] + k * 10 * (i.isEven ? 1 : -1));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p[3], height: p[3] * 0.55), Paint()..color = colors[i % colors.length].withValues(alpha: (1.1 - fall).clamp(0.0, 1.0)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}

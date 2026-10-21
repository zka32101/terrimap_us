import 'package:flutter/material.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import '../a11y.dart';
import '../app_state.dart';

/// 地図の色の見方: クリア前(白)・難易度ごとのクリアの色・まだ遊べない州(灰色)。地図の左下に重ねて出す(場所を取らないので、文字を大きくしても収まる)。
class ClearLegend extends StatelessWidget {
  final AppState app;

  /// まだ遊べない州があるとき(購入前)だけ、灰色の説明を出す。
  final bool showLocked;
  const ClearLegend({super.key, required this.app, this.showLocked = false});

  @override
  Widget build(BuildContext context) {
    final ui = app.ui, s = app.s;
    Widget row(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF455A64), width: 0.6)),
          ),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black87)),
        ]);
    return Positioned(
      key: const ValueKey('clear-legend'),
      left: 8,
      bottom: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row(A11yPalette.clearColor(null), s.t('legend.notCleared')),
                for (final d in Difficulty.values) row(A11yPalette.clearColor(d), ui.t('difficulty.${d.name}')),
                if (showLocked) row(A11yPalette.lockedColor, s.t('legend.locked')),
              ]),
        ),
      ),
    );
  }
}

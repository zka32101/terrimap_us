import 'package:flutter/material.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/i18n/ui_strings.dart';

import '../a11y.dart';

/// 地図の色の見方: 難易度ごとのクリアの色。地図の左下に重ねて出す(場所を取らないので、文字を大きくしても収まる)。
class ClearLegend extends StatelessWidget {
  final UiStrings ui;
  const ClearLegend({super.key, required this.ui});

  @override
  Widget build(BuildContext context) {
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
                for (final d in Difficulty.values)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: A11yPalette.clearColor(d),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF455A64), width: 0.6)),
                    ),
                    const SizedBox(width: 4),
                    Text(ui.t('difficulty.${d.name}'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.black87)),
                  ]),
              ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/progress/region_progress.dart';

/// 画面の色。通常は緑と赤、色覚に配慮するときは青とオレンジ（赤と緑を使わない）。
class A11yPalette {
  final bool colorBlind;
  const A11yPalette(this.colorBlind);

  /// 地図の色（習得・ミス・未出題）。
  Color region(RegionState s) => colorBlind ? colorBlindRegionColor(s) : defaultRegionColor(s);

  /// バトルの地図の色: その州をクリアした一番むずかしい難易度の色。クリアしていなければ薄い灰色。
  /// 赤と緑を使わない色の組み合わせなので、色覚に配慮するときも同じ色を使う。
  static Color clearColor(Difficulty? best) => switch (best) {
        null => const Color(0xFFFFFFFF),
        Difficulty.easy => const Color(0xFF90CAF9),
        Difficulty.normal => const Color(0xFFFFB74D),
        Difficulty.hard => const Color(0xFF7E57C2),
      };

  /// まだ遊べない州(購入前)の色。クリア前の白よりはっきり暗く、クリアの3色とは違う灰色。
  static const Color lockedColor = Color(0xFFCFD8DC);

  /// 地図の上の正解・不正解の強調。
  Color get mapOk => answerCorrectColor(colorBlind: colorBlind);
  Color get mapNg => answerWrongColor(colorBlind: colorBlind);

  /// 選択肢のボタンの色。
  Color get choiceOk => colorBlind ? const Color(0xFF64B5F6) : Colors.green.shade300;
  Color get choiceNg => colorBlind ? const Color(0xFFFFB74D) : Colors.red.shade200;

  /// 「正解！」「おしい」の文字色。
  Color get textOk => colorBlind ? const Color(0xFF0D47A1) : Colors.green.shade800;
  Color get textNg => colorBlind ? const Color(0xFFE65100) : Colors.red.shade800;
}

import 'package:flutter/material.dart';
import 'package:terrimap_core/progress/region_progress.dart';

/// 画面の色。通常は緑と赤、色覚に配慮するときは青とオレンジ（赤と緑を使わない）。
class A11yPalette {
  final bool colorBlind;
  const A11yPalette(this.colorBlind);

  /// 地図の色（習得・ミス・未出題）。
  Color region(RegionState s) => colorBlind ? colorBlindRegionColor(s) : defaultRegionColor(s);

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

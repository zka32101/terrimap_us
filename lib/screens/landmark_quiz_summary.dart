import 'package:flutter/material.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';

import '../app_state.dart';

/// 名所クイズの結果: 正答率と、間違えた名所（名前と州）。
class LandmarkQuizSummary extends StatelessWidget {
  final AppState app;
  final List<bool> results;
  final List<Question> questions;
  const LandmarkQuizSummary({super.key, required this.app, required this.results, required this.questions});

  @override
  Widget build(BuildContext context) {
    final ui = app.ui;
    final score = results.where((e) => e).length;
    final pct = results.isEmpty ? 0 : (score * 100 / results.length).round();
    final missed = [
      for (var i = 0; i < results.length && i < questions.length; i++)
        if (!results[i]) '${app.landmarkName(questions[i].subjectId)} · ${app.s.regionName(questions[i].correctId)}',
    ];
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$score / ${results.length}  (${ui.t('landmarkQuiz.accuracy', {'n': pct})})'),
      const SizedBox(height: 8),
      if (missed.isEmpty)
        Text(ui.t('landmarkQuiz.perfect'), key: const ValueKey('landmark-perfect'))
      else ...[
        Text(ui.t('landmarkQuiz.missed'), style: const TextStyle(fontWeight: FontWeight.bold)),
        for (var i = 0; i < missed.length; i++) Text('・${missed[i]}', key: ValueKey('landmark-missed-$i')),
      ],
    ]);
  }
}

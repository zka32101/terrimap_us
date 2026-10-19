import 'package:flutter/material.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_core/map/region_map_view.dart';
import 'package:terrimap_core/map/region_silhouette.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';

import '../app_state.dart';

/// 出題リストを順に解く画面。終了時に正誤の一覧(true=正解)を返す。
class QuizScreen extends StatefulWidget {
  final AppState app;
  final List<Question> questions;
  const QuizScreen({super.key, required this.app, required this.questions});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  final List<bool> _results = [];
  String? _answered; // 回答済みなら選んだ(タップした)地域id
  ArtSet? _art; // 名所の画像（読めなければ地図だけで出す）

  @override
  void initState() {
    super.initState();
    widget.app.art().then((a) {
      if (mounted) setState(() => _art = a);
    }, onError: (_) {});
  }

  Question get _q => widget.questions[_index];
  bool get _done => _answered != null;

  Future<void> _answer(String id) async {
    if (_done) return;
    final ok = _q.isCorrect(id);
    widget.app.sfx(ok ? 'correct' : 'wrong');
    setState(() {
      _answered = id;
      _results.add(ok);
    });
    await widget.app.record(_q.targetId, correct: ok);
  }

  void _next() {
    if (_index + 1 >= widget.questions.length) {
      Navigator.of(context).pop(_results);
      return;
    }
    setState(() {
      _index++;
      _answered = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.app.s;
    final q = _q;
    return Scaffold(
      appBar: AppBar(title: Text('${_index + 1} / ${widget.questions.length}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(_prompt(s, q), style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Expanded(child: _visual(q)),
            const SizedBox(height: 12),
            if (q.type != QuestionType.locateOnMap) ..._choices(q),
            if (_done) _feedback(s, q),
          ]),
        ),
      ),
    );
  }

  String _prompt(dynamic s, Question q) {
    switch (q.type) {
      case QuestionType.locateOnMap:
        return '${s.t('locate')}\n${s.regionName(q.targetId)}';
      case QuestionType.nameFromMap:
        return s.t('nameFromMap');
      case QuestionType.capitalFromName:
        return '${s.t('capitalFromName')}\n${s.regionName(q.targetId)}';
      case QuestionType.nameFromCapital:
        return '${s.t('nameFromCapital')}\n${s.capitalName(q.targetId)}';
      case QuestionType.silhouette:
        return s.t('silhouette');
      case QuestionType.neighborOf:
        return '${s.t('neighborOf')}\n${s.regionName(q.targetId)}';
      case QuestionType.landmarkOf:
        return '${s.t('landmarkOf')}\n${widget.app.landmarkName(q.subjectId)}';
    }
  }

  Widget _visual(Question q) {
    final pack = widget.app.pack;
    switch (q.type) {
      case QuestionType.locateOnMap:
        return RegionMapView(
          pack: pack,
          showZoomControls: true,
          onTap: _done ? null : _answer,
          colorOf: (id) {
            if (!_done) return const Color(0xFFECEFF1);
            if (id == q.targetId) return const Color(0xFF66BB6A);
            if (id == _answered) return const Color(0xFFEF9A9A);
            return const Color(0xFFECEFF1);
          },
        );
      case QuestionType.nameFromMap:
      case QuestionType.neighborOf:
        return RegionMapView(
          pack: pack,
          showZoomControls: true,
          colorOf: (id) => id == q.targetId ? const Color(0xFFFFB300) : const Color(0xFFECEFF1),
        );
      case QuestionType.landmarkOf:
        final img = _done ? null : (q.subjectId == null ? null : _art?.landmark(q.subjectId!));
        if (img != null) {
          return RawImage(key: ValueKey('quiz-landmark-${q.subjectId}'), image: img, fit: BoxFit.contain);
        }
        return RegionMapView(
          pack: pack,
          showZoomControls: true,
          colorOf: (id) => _done && id == q.correctId ? const Color(0xFF66BB6A) : const Color(0xFFECEFF1),
        );
      case QuestionType.silhouette:
        return RegionSilhouette(pack: pack, regionId: q.targetId);
      case QuestionType.capitalFromName:
      case QuestionType.nameFromCapital:
        return RegionMapView(
          pack: pack,
          showZoomControls: true,
          colorOf: (id) => id == q.targetId && q.type == QuestionType.capitalFromName
              ? const Color(0xFFFFB300)
              : const Color(0xFFECEFF1),
        );
    }
  }

  List<Widget> _choices(Question q) {
    final s = widget.app.s;
    String label(String id) =>
        q.type == QuestionType.capitalFromName ? s.capitalName(id) : s.regionName(id);
    return [
      for (final id in q.choiceIds)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: !_done
                    ? null
                    : id == q.correctId
                        ? Colors.green.shade300
                        : id == _answered
                            ? Colors.red.shade200
                            : null,
              ),
              onPressed: _done ? null : () => _answer(id),
              child: Text(label(id)),
            ),
          ),
        ),
    ];
  }

  Widget _feedback(dynamic s, Question q) {
    final ok = _answered == q.correctId;
    return Column(children: [
      Text(ok ? s.t('correct') : '${s.t('wrong')} ${s.t('answerWas')} ${s.regionName(q.correctId)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: ok ? Colors.green.shade800 : Colors.red.shade800)),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _next,
        child: Text(_index + 1 >= widget.questions.length ? s.t('finish') : s.t('next')),
      ),
    ]);
  }
}

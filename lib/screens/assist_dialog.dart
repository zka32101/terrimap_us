import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terrimap_core/map/region_map_view.dart';
import 'package:terrimap_core/map/region_silhouette.dart';
import 'package:terrimap_core/quiz/quiz_engine.dart';

import '../app_state.dart';

/// バトル中のクイズ連動の1問（スキル選択・修理）。正解なら true、不正解・時間切れなら false を返す。
/// [timeLimit] が null でなければ、その秒数で時間切れ（hard は10秒）。
Future<bool> showAssistQuestion(BuildContext context, AppState app, Question q, {required String title, double? timeLimit}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AssistDialog(app: app, q: q, title: title, timeLimit: timeLimit),
  );
  return r ?? false;
}

class _AssistDialog extends StatefulWidget {
  final AppState app;
  final Question q;
  final String title;
  final double? timeLimit;
  const _AssistDialog({required this.app, required this.q, required this.title, this.timeLimit});
  @override
  State<_AssistDialog> createState() => _AssistDialogState();
}

class _AssistDialogState extends State<_AssistDialog> {
  Timer? _timer;
  late double _left = widget.timeLimit ?? 0;
  String? _picked;

  @override
  void initState() {
    super.initState();
    if (widget.timeLimit != null) {
      _timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
        if (!mounted || _picked != null) return;
        setState(() => _left -= 0.25);
        if (_left <= 0) _finish('', false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _finish(String id, bool ok) async {
    if (_picked != null) return;
    _timer?.cancel();
    setState(() => _picked = id);
    // 勉強の記録にも反映する（バトルで間違えた州は、復習に出やすくなる）
    await widget.app.record(widget.q.targetId, correct: ok);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop(ok);
  }

  String _prompt() {
    final s = widget.app.s, q = widget.q;
    switch (q.type) {
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
      case QuestionType.locateOnMap:
        return s.regionName(q.targetId);
    }
  }

  Widget _visual() {
    final pack = widget.app.pack, q = widget.q;
    if (q.type == QuestionType.silhouette) return RegionSilhouette(pack: pack, regionId: q.targetId);
    if (q.type == QuestionType.nameFromCapital) return const SizedBox.shrink();
    if (q.type == QuestionType.landmarkOf) {
      return RegionMapView(pack: pack, colorOf: (id) => _picked != null && id == q.correctId ? widget.app.palette.mapOk : const Color(0xFFECEFF1));
    }
    return RegionMapView(pack: pack, colorOf: (id) => id == q.targetId ? const Color(0xFFFFB300) : const Color(0xFFECEFF1));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.app.s, q = widget.q;
    String label(String id) => q.type == QuestionType.capitalFromName ? s.capitalName(id) : s.regionName(id);
    return AlertDialog(
      title: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.timeLimit != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(value: (_left / widget.timeLimit!).clamp(0.0, 1.0)),
              ),
            Text(_prompt(), textAlign: TextAlign.center),
            if (q.type != QuestionType.nameFromCapital) SizedBox(height: 160, child: _visual()),
            const SizedBox(height: 8),
            for (final id in q.choiceIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: _picked == null
                          ? null
                          : id == q.correctId
                              ? widget.app.palette.choiceOk
                              : id == _picked
                                  ? widget.app.palette.choiceNg
                                  : null,
                    ),
                    onPressed: _picked != null ? null : () => _finish(id, q.isCorrect(id)),
                    child: Text(label(id)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

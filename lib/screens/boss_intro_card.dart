import 'package:flutter/material.dart';

/// ボスが出たときに盤面の上に出すカード。ボスの名前、物語の種類（伝説・伝記・歴史）、事実の注記。タップで閉じる。
class BossIntroCard extends StatelessWidget {
  final String title; // 例: 「ボス: ラインの水の精」
  final String basisLabel; // 例: 「伝説」
  final String fact;
  final VoidCallback onClose;
  const BossIntroCard({super.key, required this.title, required this.basisLabel, required this.fact, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('boss-intro'),
      color: cs.errorContainer,
      elevation: 6,
      child: InkWell(
        onTap: onClose,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('⚠ ', style: TextStyle(fontSize: 18)),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Chip(label: Text(basisLabel), visualDensity: VisualDensity.compact),
            ]),
            if (fact.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(fact, style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
      ),
    );
  }
}

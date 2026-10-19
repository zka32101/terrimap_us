import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';

/// 画像のシェア。テストでは何もしない [NoopSharer]。
abstract class Sharer {
  const Sharer();
  Future<void> shareImage(Uint8List png, String text);
}

class NoopSharer extends Sharer {
  const NoopSharer();
  @override
  Future<void> shareImage(Uint8List png, String text) async {}
}

/// 実機用。シェアシートを出す（出せない端末でもアプリは止めない）。
class PlatformSharer extends Sharer {
  const PlatformSharer();
  @override
  Future<void> shareImage(Uint8List png, String text) async {
    try {
      await Share.shareXFiles([XFile.fromData(png, mimeType: 'image/png', name: 'card.png')], text: text);
    } catch (_) {}
  }
}

/// シェア用のカードの中身。
class ShareCardData {
  final String heading; // 上の小さい見出し
  final String title; // 大きい題
  final String? subtitle;
  final List<(String, String)> rows; // 左: 項目、右: 値
  final ui.Image? image;
  const ShareCardData({required this.heading, required this.title, this.subtitle, this.rows = const [], this.image});
}

/// シェア用のカード（縦長。画像にして送る）。
class ShareCard extends StatelessWidget {
  final String appTitle;
  final ShareCardData data;
  const ShareCard({super.key, required this.appTitle, required this.data});

  static const width = 360.0, height = 450.0;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: fg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data.heading, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(data.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          if (data.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(data.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Colors.white70)),
          ],
          const SizedBox(height: 12),
          if (data.image != null)
            Expanded(child: Center(child: RawImage(image: data.image, fit: BoxFit.contain)))
          else
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final r in data.rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(r.$1, style: const TextStyle(fontSize: 16))),
                      Text(r.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ]),
            ),
          const SizedBox(height: 8),
          Text(appTitle, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ]),
      ),
    );
  }
}

/// カードを見せて、「画像でシェア」で送る。
Future<void> showShareCard(BuildContext context, AppState app, ShareCardData data) {
  final key = GlobalKey();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('share-card-dialog'),
      contentPadding: const EdgeInsets.all(12),
      content: SingleChildScrollView(
        child: FittedBox(
          child: RepaintBoundary(key: key, child: ShareCard(appTitle: app.s.t('appTitle'), data: data)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.ui.t('share.close'))),
        FilledButton.icon(
          key: const ValueKey('share-card-send'),
          icon: const Icon(Icons.ios_share),
          label: Text(app.ui.t('share.send')),
          onPressed: () async {
            final png = await capturePng(key);
            if (png != null) await app.sharer.shareImage(png, app.s.t('appTitle'));
          },
        ),
      ],
    ),
  );
}

/// RepaintBoundary を PNG にする（解像度は3倍）。
Future<Uint8List?> capturePng(GlobalKey key, {double pixelRatio = 3}) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/screens/daily_landmark_card.dart';
import 'package:terrimap_us/screens/stats_screen.dart';
import 'package:terrimap_us/share_card.dart';

class _Sharer extends Sharer {
  final sent = <Uint8List>[];
  @override
  Future<void> shareImage(Uint8List png, String text) async => sent.add(png);
}

bool _isPng(Uint8List b) => b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('シェア: 統計の「画像でシェア」で、進み具合のカードが PNG になって渡る', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    final sharer = _Sharer();
    app.sharer = sharer;
    await t.pumpWidget(MaterialApp(home: StatsScreen(app: app)));
    await t.tap(find.byKey(const ValueKey('stats-share')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('share-card-dialog')), findsOneWidget);
    expect(find.byType(ShareCard), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('share-card-send')));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(sharer.sent.length, 1);
    expect(_isPng(sharer.sent.first), true);
  });

  testWidgets('シェア: 今日の名所カードから、名所のカードをシェアできる', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    app.today = () => '2026-10-19';
    final sharer = _Sharer();
    app.sharer = sharer;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: DailyLandmarkCard(app: app, art: const ArtSet()))));
    await t.tap(find.byKey(const ValueKey('daily-landmark-share')));
    await t.pumpAndSettle();
    expect(find.byType(ShareCard), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('share-card-send')));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(_isPng(sharer.sent.single), true);
  });
}

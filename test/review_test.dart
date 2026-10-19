import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ReviewPromptService, FakeReviewBackend)> service() async {
    final backend = FakeReviewBackend();
    final s = ReviewPromptService(
      store: InMemoryReviewStore(),
      backend: backend,
      rules: const ReviewPromptRules(minDaysSinceFirstLaunch: 0, minPositiveMoments: 1),
    );
    await s.load();
    return (s, backend);
  }

  Future<void> open(WidgetTester t, AppState app, ReviewPromptService s) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (c) => TextButton(onPressed: () => showReviewPrePrompt(c, s, strings: app.s.kit), child: const Text('go'))),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
  }

  testWidgets('レビュー: 勝利が溜まるまでは出ない。溜まると「楽しんでいますか？」が出て、はいで依頼される', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    final (s, backend) = await service();
    expect(s.evaluate(), ReviewDecision.notEnoughMoments);
    await open(t, app, s);
    expect(find.text('Are you enjoying the app?'), findsNothing); // まだ出ない
    await s.recordPositiveMoment();
    await open(t, app, s);
    expect(find.text('Are you enjoying the app?'), findsOneWidget);
    await t.tap(find.text('Yes'));
    await t.pumpAndSettle();
    expect(backend.requestCount, 1);
    expect(s.evaluate(), isNot(ReviewDecision.ask)); // 頼んだあとは、すぐには頼まない
  });

  testWidgets('レビュー: 「いいえ」ならレビューは頼まず、しばらく控える', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    final (s, backend) = await service();
    await s.recordPositiveMoment();
    await open(t, app, s);
    await t.tap(find.text('Not really'));
    await t.pumpAndSettle();
    expect(backend.requestCount, 0);
    expect(s.evaluate(), ReviewDecision.declinedRecently);
  });
}

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/main.dart';
import 'package:terrimap_us/monetization.dart';
import 'package:terrimap_us/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('名物クイズの文言と題材の名前: 全言語で問題文がそろい、題材名は言語になければ英語', () async {
    final app = await AppState.load();
    expect(app.knowledgeRegionIds, isNotEmpty);
    for (final lang in Strings.supported) {
      await app.setLang(lang);
      expect(app.s.t('knowledgeQuiz'), isNot('knowledgeQuiz'), reason: lang);
      for (final kind in const ['food', 'product', 'culture', 'nature']) {
        expect(app.s.t('knowledgeOf.$kind'), isNot('knowledgeOf.$kind'), reason: '$lang $kind');
      }
    }
    final any = app.pack.facts!.knowledge.first;
    await app.setLang('fr');
    expect(app.knowledgeName(any.id), any.name['en']); // フランス語の名前がなければ英語
    await app.setLang('ja');
    expect(app.knowledgeName(any.id), any.name['ja']);
    expect(app.knowledgeKind(any.id), any.kind);
    expect(app.knowledgeName('nope'), '');
    expect(app.knowledgeKind('nope'), 'culture');
  });

  testWidgets('名物クイズ: ホームのボタンから、深い知識の問題だけが出る。解くと正解の州が地図に出る', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await t.pumpWidget(ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(Monetization.fakeEntitlement()),
        optionalAdGateProvider.overrideWithValue(null),
      ],
      child: TerrimapApp(app: app),
    ));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('knowledge-quiz')));
    await t.pumpAndSettle();
    final prompts = [for (final k in const ['food', 'product', 'culture', 'nature']) app.s.t('knowledgeOf.$k')];
    expect(prompts.any((p) => find.textContaining(p).evaluate().isNotEmpty), isTrue);
    expect(find.text('1 / 10'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}

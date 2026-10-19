import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle_ui/art_set.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/screens/daily_landmark_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('今日の名所: 日替わりの名所が名前と州つきで出る（画像がなくてもアイコンで出る）', (t) async {
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    app.today = () => '2026-10-19';
    await t.pumpWidget(MaterialApp(home: Scaffold(body: DailyLandmarkCard(app: app, art: const ArtSet()))));
    expect(find.byKey(const ValueKey('daily-landmark')), findsOneWidget);
    expect(find.text(app.ui.t('dailyLandmark.title')), findsOneWidget);
    String line() => (t.widget<Text>(find.descendant(of: find.byType(ListTile), matching: find.byType(Text)).last)).data!;
    final first = line();
    expect(first, contains(' · '));
    app.today = () => '2026-10-19';
    expect(line(), first);
  });
}

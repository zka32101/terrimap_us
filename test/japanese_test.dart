import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('日本語: 画面の文言・州名・州都・名所名が日本語で引ける。足りなければ英語', () async {
    final app = await AppState.load();
    await app.setLang('ja');
    expect(app.s.t('quiz'), 'クイズ');
    expect(app.ui.t('hud.pause'), 'ポーズ');
    final r = app.pack.regions.first;
    expect(RegExp(r'[ぁ-んァ-ヶ一-龠]').hasMatch(app.s.regionName(r.id)), true);
    expect(RegExp(r'[ぁ-んァ-ヶ一-龠]').hasMatch(app.s.capitalName(r.id)), true);
    final lm = app.pack.facts!.landmarks.first;
    expect(RegExp(r'[ぁ-んァ-ヶ一-龠]').hasMatch(lm.nameIn('ja')), true);
    for (final l in app.pack.facts!.landmarks) {
      expect(l.name['ja'], isNotEmpty, reason: l.id);
    }
    for (final reg in app.pack.regions) {
      expect(app.s.regionName(reg.id), isNot(reg.id));
    }
  });
}

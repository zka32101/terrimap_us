import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('対応言語のすべてで、州名・州都名・名所名・アプリの文言・画面の文言がそろっている', () async {
    final app = await AppState.load();
    expect(Strings.supported.length, greaterThanOrEqualTo(10));
    for (final lang in Strings.supported) {
      await app.setLang(lang);
      expect(app.pack.strings.containsKey(lang), true, reason: lang);
      for (final r in app.pack.regions) {
        expect(app.s.regionName(r.id), isNotEmpty, reason: '$lang ${r.id}');
        expect(app.s.capitalName(r.id), isNotEmpty, reason: '$lang ${r.id}');
      }
      for (final l in app.pack.facts!.landmarks) {
        expect(l.name.containsKey(lang), true, reason: '$lang ${l.id}');
      }
      expect(app.s.t('quiz'), isNotEmpty);
      expect(app.s.t('appTitle'), isNot('appTitle'));
      expect(app.ui.t('hud.pause'), isNot('hud.pause'));
      if (lang != 'en') {
        // 英語のままの訳漏れがないこと（画面の文言のうち、固有名でないもの）
        expect(app.ui.t('hud.startWave'), isNot('Start next wave'), reason: lang);
      }
    }
  });
}

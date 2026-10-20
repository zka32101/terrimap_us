import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('組み合わせボーナスの説明: 初めは未表示で、表示済みにすると残る。文言は11言語にある', () async {
    final a = await AppState.load();
    expect(a.synergyHintSeen, false);
    await a.setSynergyHintSeen();
    expect((await AppState.load()).synergyHintSeen, true);
    for (final l in ['en', 'ja', 'de', 'fr', 'es', 'it', 'pt', 'nl', 'tr', 'ko', 'zh']) {
      await a.setLang(l);
      final t = a.ui.t('synergy.hint');
      expect(t, isNotEmpty, reason: l);
      expect(t, isNot('synergy.hint'), reason: l);
    }
  });
}

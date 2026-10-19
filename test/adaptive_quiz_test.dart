import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('かしこいクイズ: 初期はオン。間違えた州の重みが上がり、オフにするとふつうのランダム（重みなし）', () async {
    final app = await AppState.load();
    expect(app.adaptiveQuiz, true);
    final ids = app.pack.regions.map((r) => r.id).toList();
    final before = app.quizWeights!;
    expect(before[ids[0]], 1.5); // まだ出題されていない
    await app.record(ids[0], correct: false);
    await app.record(ids[0], correct: false);
    await app.record(ids[1], correct: true);
    final w = app.quizWeights!;
    expect(w[ids[0]], 3.0); // 2回間違えた: 2.0 + 0.5 * 2
    expect(w[ids[1]], 0.4); // 習得済みは軽い
    expect(w[ids[2]], 1.5);
    await app.setAdaptiveQuiz(false);
    expect(app.quizWeights, isNull);
    expect((await AppState.load()).adaptiveQuiz, false); // 再起動しても残る
  });
}

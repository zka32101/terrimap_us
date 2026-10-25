import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_core/battle/difficulty.dart';
import 'package:terrimap_core/battle/grid.dart';
import 'package:terrimap_core/battle/stage_generator.dart';
import 'package:terrimap_us/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('敵の見た目違い: ステージの州・地方に合うものだけが、ArtSet に入る', () async {
    final app = await AppState.load();
    final gen = StageGenerator(app.pack);
    final west = await app.art(stage: gen.generate('US-CA', Difficulty.normal)); // 西
    final ne = await app.art(stage: gen.generate('US-NY', Difficulty.normal)); // 北東
    expect(west.enemyVariants['armored'], ['fossil_turtle']);
    expect(ne.enemyVariants['armored'], ['scrap_bull']);
    // どこでも出るものは、どの州にも入る
    expect(west.enemyVariants['speedy'], ['jackalope']);
    expect(ne.enemyVariants['speedy'], ['jackalope', 'root_runner']);
    // 基本の見た目は、見た目違いの候補に入らない
    for (final a in [west, ne]) {
      for (final e in a.enemyVariants.entries) {
        expect(e.value, isNot(contains(a.enemySkins[e.key])));
      }
    }
    // ステージを渡さないとき(図鑑・クイズなど)は、見た目違いなし
    expect((await app.art()).enemyVariants, isEmpty);
  });

  test('敵の見た目違い: 地方決戦でも、その地方の見た目違いが入る', () async {
    final app = await AppState.load();
    final st = StageGenerator(app.pack).generate('west', Difficulty.normal, kind: StageKind.regional);
    final art = await app.art(stage: st);
    expect(art.enemyVariants['normal'], ['dust_imp']);
    expect(art.enemyVariants['armored'], ['fossil_turtle']);
    expect(art.enemyVariants['healer'], containsAll(['honey_sprite', 'rain_cloud_sprite']));
  });
}

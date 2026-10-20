import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/monetization.dart';
import 'package:terrimap_us/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('バトルの演出: 初期はオンで、切り替えは再起動しても残る。オフなら振動も出さない', () async {
    final app = await AppState.load();
    expect(app.battleFx, true);
    app.haptic(); // 例外にならない
    await app.setBattleFx(false);
    expect(app.battleFx, false);
    app.haptic(heavy: true);
    expect((await AppState.load()).battleFx, false);
  });

  testWidgets('設定: 「バトルの演出」のスイッチで切り替えられる', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = await t.runAsync(AppState.load) as AppState;
    await app.setLang('en');
    await t.pumpWidget(ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(Monetization.fakeEntitlement()),
        optionalAdGateProvider.overrideWithValue(null),
      ],
      child: MaterialApp(home: SettingsScreen(app: app)),
    ));
    await t.pump();
    final sw = find.byKey(const ValueKey('battle-fx-switch'));
    await t.scrollUntilVisible(sw, 300, scrollable: find.byType(Scrollable).first);
    expect(t.widget<SwitchListTile>(sw).value, true);
    await t.tap(sw);
    await t.pump();
    expect(app.battleFx, false);
    expect(find.text('Battle effects'), findsWidgets);
  });
}

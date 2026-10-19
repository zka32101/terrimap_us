import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/reminders.dart';
import 'package:terrimap_us/sound.dart';

class _Sound extends Sound {
  final played = <String>[];
  bool bgm = false;
  @override
  Future<void> play(String name) async => played.add(name);
  @override
  Future<void> setBgm(bool on) async => bgm = on;
}

class _Reminders extends Reminders {
  final bool allow;
  bool on = false;
  _Reminders(this.allow);
  @override
  Future<bool> enable(String title, String body) async => on = allow;
  @override
  Future<void> disable() async => on = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('効果音: 初期はオン、オフにすると鳴らない。BGM は初期オフで、切り替えが音の側に伝わる', () async {
    final app = await AppState.load();
    final snd = _Sound();
    app.sound = snd;
    expect((app.sfxOn, app.bgmOn), (true, false));
    app.sfx('correct');
    await app.setSfx(false);
    app.sfx('wrong');
    expect(snd.played, ['correct']);
    await app.setBgm(true);
    expect((app.bgmOn, snd.bgm), (true, true));
  });

  test('リマインダー: 許可されればオン、許可されなければオフのまま。オフにすると通知も止まる', () async {
    final app = await AppState.load();
    final denied = _Reminders(false);
    app.reminders = denied;
    expect(await app.setReminder(true), false);
    expect(app.reminderOn, false);
    final ok = _Reminders(true);
    app.reminders = ok;
    expect(await app.setReminder(true), true);
    expect((app.reminderOn, ok.on), (true, true));
    await app.setReminder(false);
    expect((app.reminderOn, ok.on), (false, false));
  });
}

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
  Future<void> setBgm(bool on, {String track = 'bgm'}) async => bgm = on;
}

class _Reminders extends Reminders {
  final bool allow;
  bool on = false;
  int? minutes;
  DateTime? rescue;
  _Reminders(this.allow);
  @override
  Future<bool> enable(String title, String body, {required int hour, required int minute}) async {
    minutes = hour * 60 + minute;
    return on = allow;
  }

  @override
  Future<void> disable() async => on = false;
  @override
  Future<void> scheduleRescue(DateTime? at, String title, String body) async => rescue = at;
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

  test('通知の時刻: 初期は20:00。変えるとオンのときだけ予約し直す', () async {
    final app = await AppState.load();
    final r = _Reminders(true);
    app.reminders = r;
    expect(app.reminderMinutes, 20 * 60);
    await app.setReminderTime(7 * 60 + 30);
    expect(r.minutes, isNull); // オフのときは予約しない
    await app.setReminder(true);
    expect(r.minutes, 7 * 60 + 30);
    await app.setReminderTime(21 * 60);
    expect((app.reminderMinutes, r.minutes), (21 * 60, 21 * 60));
  });

  test('ストリーク救済: 連続中で今日がまだなら予約、済ませたら取り消し。通知がオフなら予約しない', () async {
    final now = DateTime.now();
    String d(DateTime x) => x.toUtc().toIso8601String().substring(0, 10);
    final yesterday = d(now.subtract(const Duration(days: 1)));
    SharedPreferences.setMockInitialValues({'daily_streak_v1': '{"current":3,"best":3,"lastDate":"$yesterday"}'});
    final app = await AppState.load();
    app.today = () => d(now);
    final r = _Reminders(true);
    app.reminders = r;
    await app.refreshRescue();
    expect(r.rescue, isNull); // 通知オフ
    await app.setReminder(true);
    // 21時前なら今日の21時、過ぎていれば予約なし
    expect(r.rescue, now.hour < 21 ? DateTime(now.year, now.month, now.day, 21) : isNull);
  });
}

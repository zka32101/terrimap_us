import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 端末内の通知（サーバーは使わない）。テストでは何もしない [NoopReminders]。
abstract class Reminders {
  const Reminders();

  /// 毎日 [hour]:[minute] の通知を始める。通知が許可されなければ false。
  Future<bool> enable(String title, String body, {required int hour, required int minute});
  Future<void> disable();

  /// ストリーク救済の通知（1回だけ）。[at] が null なら取り消す。
  Future<void> scheduleRescue(DateTime? at, String title, String body);
}

class NoopReminders extends Reminders {
  const NoopReminders();
  @override
  Future<bool> enable(String title, String body, {required int hour, required int minute}) async => true;
  @override
  Future<void> disable() async {}
  @override
  Future<void> scheduleRescue(DateTime? at, String title, String body) async {}
}

class LocalReminders extends Reminders {
  static const _dailyId = 1, _rescueId = 2;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {} // 取れなければ UTC のまま（時刻がずれるだけで、通知は届く）
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
    _ready = true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('daily_reminder', 'Daily reminder'),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<bool> enable(String title, String body, {required int hour, required int minute}) async {
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final ok = (await android?.requestNotificationsPermission()) ?? (await ios?.requestPermissions(alert: true, sound: true)) ?? true;
      if (!ok) return false;
      final now = tz.TZDateTime.now(tz.local);
      var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        _dailyId,
        title,
        body,
        first,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // 毎日同じ時刻
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disable() async {
    try {
      await _init();
      await _plugin.cancel(_dailyId);
      await _plugin.cancel(_rescueId);
    } catch (_) {}
  }

  @override
  Future<void> scheduleRescue(DateTime? at, String title, String body) async {
    try {
      await _init();
      await _plugin.cancel(_rescueId);
      if (at == null) return;
      await _plugin.zonedSchedule(
        _rescueId,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }
}

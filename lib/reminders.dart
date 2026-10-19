import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 毎日のリマインダー（端末内の通知。サーバーは使わない）。テストでは [NoopReminders]。
abstract class Reminders {
  const Reminders();

  /// 毎日の通知を始める。通知が許可されなければ false。
  Future<bool> enable(String title, String body);
  Future<void> disable();
}

class NoopReminders extends Reminders {
  const NoopReminders();
  @override
  Future<bool> enable(String title, String body) async => true;
  @override
  Future<void> disable() async {}
}

class LocalReminders extends Reminders {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
    _ready = true;
  }

  @override
  Future<bool> enable(String title, String body) async {
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final ok = (await android?.requestNotificationsPermission()) ?? (await ios?.requestPermissions(alert: true, sound: true)) ?? true;
      if (!ok) return false;
      await _plugin.periodicallyShow(
        _id,
        title,
        body,
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails('daily_reminder', 'Daily reminder'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
      await _plugin.cancel(_id);
    } catch (_) {}
  }
}

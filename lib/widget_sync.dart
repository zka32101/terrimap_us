import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// ホーム画面ウィジェットに見せる中身。文言は表示言語に直してから渡す（ウィジェット側は文字を出すだけ）。
class WidgetData {
  final String streak; // 例: 「3日」
  final String landmark; // 今日の名所の名前（なければ空）
  final String status; // 例: 「✅ 今日のチャレンジ」
  const WidgetData({required this.streak, required this.landmark, required this.status});

  @override
  bool operator ==(Object other) =>
      other is WidgetData && other.streak == streak && other.landmark == landmark && other.status == status;
  @override
  int get hashCode => Object.hash(streak, landmark, status);
}

/// ウィジェットへの書き出し。テストでは何もしない [NoopWidgetSync] か、記録するだけの偽物を使う。
abstract class WidgetSync {
  const WidgetSync();
  Future<void> update(WidgetData data);
}

class NoopWidgetSync extends WidgetSync {
  const NoopWidgetSync();
  @override
  Future<void> update(WidgetData data) async {}
}

/// ホーム画面ウィジェットへ書き出す。Android は `StreakWidgetProvider`、iOS は WidgetKit の `StreakWidget`（Xcode で拡張を作ったとき）。失敗してもアプリは止めない。
class HomeWidgetSync extends WidgetSync {
  static const androidProvider = 'dev.terrimap.terrimap_us.StreakWidgetProvider';
  /// iOS: App Group の id（Runner とウィジェット拡張の両方で有効にする）と、ウィジェットの名前（`ios/StreakWidget/StreakWidget.swift` の kind）。
  static const iosAppGroup = 'group.dev.terrimap.terrimapUs';
  static const iosWidgetName = 'StreakWidget';
  const HomeWidgetSync();

  @override
  Future<void> update(WidgetData data) async {
    try {
      await HomeWidget.setAppGroupId(iosAppGroup); // iOS だけで働く。拡張が未設定でも、失敗はここで握りつぶす
      await HomeWidget.saveWidgetData<String>('streak', data.streak);
      await HomeWidget.saveWidgetData<String>('landmark', data.landmark);
      await HomeWidget.saveWidgetData<String>('status', data.status);
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider, iOSName: iosWidgetName);
    } catch (e) {
      debugPrint('widget update failed: $e');
    }
  }
}

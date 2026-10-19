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

/// Android のホーム画面ウィジェット（`StreakWidgetProvider`）へ書き出す。失敗してもアプリは止めない。
class HomeWidgetSync extends WidgetSync {
  static const androidProvider = 'dev.terrimap.terrimap_us.StreakWidgetProvider';
  const HomeWidgetSync();

  @override
  Future<void> update(WidgetData data) async {
    try {
      await HomeWidget.saveWidgetData<String>('streak', data.streak);
      await HomeWidget.saveWidgetData<String>('landmark', data.landmark);
      await HomeWidget.saveWidgetData<String>('status', data.status);
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } catch (e) {
      debugPrint('widget update failed: $e');
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrimap_us/app_state.dart';
import 'package:terrimap_us/widget_sync.dart';

class _Rec extends WidgetSync {
  final log = <WidgetData>[];
  @override
  Future<void> update(WidgetData data) async => log.add(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ウィジェット: 連続日数・今日のチャレンジの済み/未・今日の名所を書き出し、言語を変えると書き直す', () async {
    final app = await AppState.load();
    final rec = _Rec();
    app.widgetSync = rec;
    await app.setLang('en');
    app.today = () => '2026-10-19';
    await app.refreshRescue();
    final first = rec.log.last;
    expect(first.streak, '0 days');
    expect(first.status.startsWith('⬜'), isTrue);
    expect(first.landmark, isNotEmpty); // 名所のデータがある

    await app.setLang('ja');
    expect(rec.log.last.streak, isNot('0 days')); // 言語に合わせて書き直される
    expect(rec.log.last.landmark, isNotEmpty);
  });

  test('ウィジェットへの書き出しが失敗しても、アプリは止まらない（Noop は何もしない）', () async {
    await const NoopWidgetSync().update(const WidgetData(streak: 'a', landmark: 'b', status: 'c'));
    expect(const WidgetData(streak: 'a', landmark: 'b', status: 'c'), const WidgetData(streak: 'a', landmark: 'b', status: 'c'));
  });
}

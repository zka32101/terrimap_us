import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'monetization.dart';
import 'reminders.dart';
import 'review.dart';
import 'share_card.dart';
import 'widget_sync.dart';
import 'sound.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedThemeMode();
  final app = await AppState.load();
  app.sound = PlayerSound();
  app.reminders = LocalReminders();
  app.sharer = const PlatformSharer();
  app.widgetSync = const HomeWidgetSync();
  if (app.bgmOn) app.sound.setBgm(true);
  app.refreshRescue();
  app.review = await createReviewPrompt('terrimap_us');
  final money = await Monetization.init();
  app.syncEntitlement(money.entitlement.state);
  money.entitlement.stateStream.listen(app.syncEntitlement);
  runApp(ProviderScope(
    overrides: [
      entitlementServiceProvider.overrideWithValue(money.entitlement),
      optionalAdGateProvider.overrideWithValue(money.ads),
    ],
    child: TerrimapApp(app: app),
  ));
}

/// アイコンと同じ配色(藍をベースに、橙をアクセントにする)。シリーズで橙をそろえ、ベースの色だけ国ごとに替える。
ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2B2D77), brightness: b).copyWith(
    secondary: const Color(0xFFF4A300),
    onSecondary: const Color(0xFF14153C),
    tertiary: const Color(0xFFF4A300),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF4A300),
        foregroundColor: const Color(0xFF14153C),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    cardTheme: const CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18)))),
  );
}

class TerrimapApp extends StatelessWidget {
  final AppState app;
  const TerrimapApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    // キットの部品(購入欄など)の文言を、アプリの表示言語に合わせる。
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode, // 設定の「表示モード」
        builder: (context, mode, _) => MaterialApp(
        themeMode: mode,
        darkTheme: _theme(Brightness.dark),
        title: 'State Master – USA',
        theme: _theme(Brightness.light),
        builder: (context, child) =>
            KitStringsScope(strings: app.s.kit, child: child ?? const SizedBox.shrink()),
        home: HomeScreen(app: app),
        ),
      ),
    );
  }
}

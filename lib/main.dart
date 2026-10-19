import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'monetization.dart';
import 'reminders.dart';
import 'review.dart';
import 'share_card.dart';
import 'sound.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedThemeMode();
  final app = await AppState.load();
  app.sound = PlayerSound();
  app.reminders = LocalReminders();
  app.sharer = const PlatformSharer();
  if (app.bgmOn) app.sound.setBgm(true);
  app.refreshRescue();
  app.review = await createReviewPrompt('terrimap_us');
  final money = await Monetization.init();
  runApp(ProviderScope(
    overrides: [
      entitlementServiceProvider.overrideWithValue(money.entitlement),
      optionalAdGateProvider.overrideWithValue(money.ads),
    ],
    child: TerrimapApp(app: app),
  ));
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
        darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), brightness: Brightness.dark, useMaterial3: true),
        title: 'State Master – USA',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), useMaterial3: true),
        builder: (context, child) =>
            KitStringsScope(strings: app.s.kit, child: child ?? const SizedBox.shrink()),
        home: HomeScreen(app: app),
        ),
      ),
    );
  }
}

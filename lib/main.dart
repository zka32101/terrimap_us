import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'monetization.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await AppState.load();
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
      builder: (context, _) => MaterialApp(
        title: 'State Master – USA',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), useMaterial3: true),
        builder: (context, child) =>
            KitStringsScope(strings: app.s.kit, child: child ?? const SizedBox.shrink()),
        home: HomeScreen(app: app),
      ),
    );
  }
}

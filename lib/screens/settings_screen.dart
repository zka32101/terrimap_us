import 'package:app_common_kit/app_common_kit.dart' as kit;
import 'package:flutter/material.dart';
import 'package:terrimap_core/i18n/languages.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../legal.dart';

/// 設定画面。キット（app_common_kit）の共通の設定画面に、このアプリ固有の項目（クイズ連動・出典）を足したもの。
/// 共通の項目: 購入、表示モード（ライト・ダーク）、言語、プライバシーポリシー・利用規約（URL を設定したとき）、データの削除、このアプリについて。
class SettingsScreen extends StatelessWidget {
  final AppState app;
  const SettingsScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.s;
        return kit.SettingsScreen(
          appName: s.t('appTitle'),
          strings: s.kit,
          showHandsFree: false, // 地図クイズには使わない
          showFeedback: false, // 送信先（Firebase）を用意してから
          languages: [for (final l in appLanguages) kit.SettingsLanguage(l.code, l.nativeName)],
          languageCode: app.lang,
          onLanguageChanged: app.setLang,
          legal: legalLinks,
          onOpenLink: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
          dataDeletion: kit.DataDeletion([kit.SharedPreferencesEraser(all: true)]), // 進捗・バトルの記録・設定。購入はストア側にあり、消えない
          onDataDeleted: (_) async {
            kit.appThemeMode.value = ThemeMode.system;
            await app.reloadFromPrefs();
            if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          },
          disclaimer: app.pack.attribution,
          extraSections: [
            kit.SettingsSection(title: app.ui.t('tutorial.replay'), children: [
              ListTile(
                key: const ValueKey('tutorial-replay'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(app.ui.t('tutorial.replay')),
                subtitle: Text(app.ui.t('tutorial.replayHelp')),
                onTap: () async {
                  await app.setTutorialDone(false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.ui.t('tutorial.replayHelp'))));
                },
              ),
            ]),
            kit.SettingsSection(title: app.ui.t('assist.setting'), children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(app.ui.t('assist.setting')),
                subtitle: Text(app.ui.t('assist.settingHelp')),
                value: app.quizAssist,
                onChanged: app.setQuizAssist,
              ),
            ]),
          ],
        );
      },
    );
  }
}

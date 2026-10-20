import 'package:app_common_kit/app_common_kit.dart' as kit;
import 'package:flutter/material.dart';
import 'package:terrimap_core/i18n/languages.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../legal.dart';
import '../looks.dart';
import 'unlock_sheet.dart';

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
            if (app.lookIds.isNotEmpty)
              kit.SettingsSection(title: s.t('looksTitle'), children: [
                ListTile(
                  key: const ValueKey('look-default'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(app.activeLook == null ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                  title: Text(s.t('looksDefault')),
                  onTap: () => app.setLook(null),
                ),
                for (final id in app.lookIds)
                  ListTile(
                    key: ValueKey('look-$id'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(app.activeLook == id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    title: Text(lookLabel(id, s.t)),
                    trailing: app.looksOwned ? null : const Icon(Icons.lock_outline),
                    // 持っていなければ、選ばずに購入の案内を出す
                    onTap: () => app.looksOwned ? app.setLook(id) : showUnlockSheet(context, app, looksOnly: true),
                  ),
              ]),
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
            kit.SettingsSection(title: app.ui.t('sound.sfx'), children: [
              SwitchListTile(
                key: const ValueKey('sfx-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(app.ui.t('sound.sfx')),
                value: app.sfxOn,
                onChanged: app.setSfx,
              ),
              SwitchListTile(
                key: const ValueKey('bgm-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(app.ui.t('sound.bgm')),
                value: app.bgmOn,
                onChanged: app.setBgm,
              ),
            ]),
            kit.SettingsSection(title: app.ui.t('reminder.setting'), children: [
              SwitchListTile(
                key: const ValueKey('reminder-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(app.ui.t('reminder.setting')),
                subtitle: Text(app.ui.t('reminder.help')),
                value: app.reminderOn,
                onChanged: (v) async {
                  final ok = await app.setReminder(v);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.ui.t('reminder.denied'))));
                  }
                },
              ),
              ListTile(
                key: const ValueKey('reminder-time'),
                contentPadding: EdgeInsets.zero,
                enabled: app.reminderOn,
                leading: const Icon(Icons.access_time),
                title: Text(app.ui.t('reminder.time')),
                trailing: Text(MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: app.reminderMinutes ~/ 60, minute: app.reminderMinutes % 60))),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: app.reminderMinutes ~/ 60, minute: app.reminderMinutes % 60),
                  );
                  if (picked != null) await app.setReminderTime(picked.hour * 60 + picked.minute);
                },
              ),
            ]),
            kit.SettingsSection(title: app.ui.t('a11y.colorBlind'), children: [
              SwitchListTile(
                key: const ValueKey('color-blind-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(app.ui.t('a11y.colorBlind')),
                subtitle: Text(app.ui.t('a11y.colorBlindHelp')),
                value: app.colorBlind,
                onChanged: app.setColorBlind,
              ),
            ]),
            kit.SettingsSection(title: app.ui.t('fx.setting'), children: [
              SwitchListTile(
                key: const ValueKey('battle-fx-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(app.ui.t('fx.setting')),
                subtitle: Text(app.ui.t('fx.help')),
                value: app.battleFx,
                onChanged: app.setBattleFx,
              ),
            ]),
            kit.SettingsSection(title: app.ui.t('adaptive.setting'), children: [
              SwitchListTile(
                key: const ValueKey('adaptive-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(app.ui.t('adaptive.setting')),
                subtitle: Text(app.ui.t('adaptive.help')),
                value: app.adaptiveQuiz,
                onChanged: app.setAdaptiveQuiz,
              ),
            ]),
            kit.SettingsSection(title: app.ui.t('assist.setting'), children: [
              SwitchListTile(
                key: const ValueKey('assist-switch'),
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

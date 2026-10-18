import 'package:app_common_kit/app_common_kit.dart' show PurchaseSection;
import 'package:flutter/material.dart';

import '../app_state.dart';
import 'package:terrimap_core/i18n/languages.dart';

class SettingsScreen extends StatelessWidget {
  final AppState app;
  const SettingsScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.s;
        return Scaffold(
          appBar: AppBar(title: Text(s.t('settings'))),
          body: ListView(children: [
            ListTile(
              title: Text(s.t('language')),
              trailing: DropdownButton<String>(
                value: app.lang,
                items: [for (final l in appLanguages) DropdownMenuItem(value: l.code, child: Text(l.nativeName))],
                onChanged: (l) {
                  if (l != null) app.setLang(l);
                },
              ),
            ),
            SwitchListTile(
              title: Text(app.ui.t('assist.setting')),
              subtitle: Text(app.ui.t('assist.settingHelp')),
              value: app.quizAssist,
              onChanged: app.setQuizAssist,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: PurchaseSection(),
            ),
            ListTile(
              title: Text(s.t('attribution')),
              subtitle: Text(app.pack.attribution),
            ),
          ]),
        );
      },
    );
  }
}

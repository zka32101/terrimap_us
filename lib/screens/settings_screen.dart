import 'package:app_common_kit/app_common_kit.dart' show PurchaseSection;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';

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
            if (Strings.supported.length > 1)
              ListTile(
                title: Text(s.t('language')),
                trailing: DropdownButton<String>(
                  value: app.lang,
                  items: [for (final l in Strings.supported) DropdownMenuItem(value: l, child: Text(l))],
                  onChanged: (l) {
                    if (l != null) app.setLang(l);
                  },
                ),
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

import 'package:flutter/material.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/app_version.dart';

Future<void> showEpitakaAboutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AboutDialog(),
  );
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.about),
      content: FutureBuilder<AppVersion>(
        future: loadAppVersion(),
        builder: (context, snapshot) {
          final version =
              snapshot.data?.display ?? (snapshot.hasError ? '—' : '…');
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('${loc.version} $version')],
          );
        },
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.ok),
        ),
      ],
    );
  }
}

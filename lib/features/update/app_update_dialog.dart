import 'package:flutter/material.dart';

import '../../core/utils/app_localizations.dart';
import 'app_update_service.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdate update;
  final AppUpdateService service;

  const AppUpdateDialog({
    super.key,
    required this.update,
    required this.service,
  });

  static Future<void> show(
    BuildContext context,
    AppUpdate update,
    AppUpdateService service,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => AppUpdateDialog(update: update, service: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.desktopUpdateAvailable),
      content: Text(loc.desktopUpdateDescription(update.version)),
      actions: [
        TextButton(
          onPressed: () async {
            await service.dismissVersion(update.version);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(loc.dontAskForThisVersion),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.later),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(loc.downloadUpdate),
          onPressed: () async {
            await service.dismissVersion(update.version);
            if (context.mounted) Navigator.of(context).pop();
            await service.openReleasePage(update.releasePage);
          },
        ),
      ],
    );
  }
}

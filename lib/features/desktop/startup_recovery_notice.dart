import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/app_localizations.dart';
import 'startup_guard.dart';

/// Tells the user, once, that the start-up guard changed the settings file,
/// so settings that went back or were reset are not a mystery.
class StartupRecoveryNotice extends StatefulWidget {
  const StartupRecoveryNotice({super.key, required this.child});

  final Widget child;

  @override
  State<StartupRecoveryNotice> createState() => _StartupRecoveryNoticeState();
}

class _StartupRecoveryNoticeState extends State<StartupRecoveryNotice> {
  @override
  void initState() {
    super.initState();
    final recovery = pendingStartupRecovery;
    pendingStartupRecovery = null;
    if (recovery == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final colors = Theme.of(context).colorScheme;
      final messenger = ScaffoldMessenger.of(context);
      // Close sits in the content, not in the snack bar's action slot, which
      // is pinned to the right edge and cannot be centred with the text.
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colors.outlineVariant, width: 1.5),
          ),
          // One line when it fits, wrapped when it does not. `Text` inside a
          // `SelectionArea` is as wide as its words; `SelectableText` would
          // fill the row and push Close to the far side.
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: colors.primary),
              const SizedBox(width: 12),
              Flexible(
                child: SelectionArea(
                  child: Text(
                    startupRecoveryText(l, recovery),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colors.primary),
                onPressed: messenger.hideCurrentSnackBar,
                child: Text(l.close),
              ),
            ],
          ),
          duration: const Duration(seconds: 12),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String startupRecoveryText(AppLocalizations l, StartupRecovery r) {
  final time = r.lastGoodTime;
  final date = time == null ? '?' : DateFormat.yMd().add_Hm().format(time);
  switch (r.cause) {
    case StartupRecoveryCause.unfinishedStart:
      return switch (r.outcome) {
        StartupRecoveryOutcome.restored =>
          l.startupRestoredAfterUnfinished(date),
        StartupRecoveryOutcome.startedEmpty => r.failedStarts >= 2
            ? l.startupEmptyAfterTwoUnfinished
            : l.startupEmptyAfterOneUnfinished,
        StartupRecoveryOutcome.stillFailing =>
          l.startupStillFailing(r.failedStarts),
      };
    case StartupRecoveryCause.unreadableFile:
      return r.outcome == StartupRecoveryOutcome.restored
          ? l.startupRestoredAfterUnreadable(date)
          : l.startupEmptyAfterUnreadable;
  }
}

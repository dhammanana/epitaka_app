import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/desktop/startup_guard.dart';
import 'package:epitaka/features/desktop/startup_recovery_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _folder = '/home/someone/.local/share/com.dn.epitaka';

final _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5A2B)),
);

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) => StartupRecoveryNotice(child: child!),
      home: const Scaffold(body: SizedBox()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(() => pendingStartupRecovery = null);

  final rows = <(String, StartupRecovery, String)>[
    (
      'did not finish, restored',
      StartupRecovery(
        cause: StartupRecoveryCause.unfinishedStart,
        outcome: StartupRecoveryOutcome.restored,
        folder: _folder,
        lastGoodTime: DateTime(2026, 11, 20, 9, 30),
        failedStarts: 1,
      ),
      'ePitaka did not finish starting last time, so it went back to your '
          'settings from 11/20/2026 09:30.',
    ),
    (
      'did not finish once, no last good copy',
      const StartupRecovery(
        cause: StartupRecoveryCause.unfinishedStart,
        outcome: StartupRecoveryOutcome.startedEmpty,
        folder: _folder,
        failedStarts: 1,
      ),
      'ePitaka did not finish starting last time, and no earlier settings '
          'were kept, so it started with default settings.',
    ),
    (
      'did not finish twice',
      const StartupRecovery(
        cause: StartupRecoveryCause.unfinishedStart,
        outcome: StartupRecoveryOutcome.startedEmpty,
        folder: _folder,
        failedStarts: 2,
      ),
      'ePitaka did not finish starting twice, so it started with default '
          'settings.',
    ),
    (
      'still failing',
      const StartupRecovery(
        cause: StartupRecoveryCause.unfinishedStart,
        outcome: StartupRecoveryOutcome.stillFailing,
        folder: _folder,
        failedStarts: 3,
      ),
      'ePitaka did not finish starting 3 times in a row, and default settings '
          'did not help.',
    ),
    (
      'could not read, restored',
      StartupRecovery(
        cause: StartupRecoveryCause.unreadableFile,
        outcome: StartupRecoveryOutcome.restored,
        folder: _folder,
        lastGoodTime: DateTime(2026, 11, 20, 9, 30),
      ),
      'ePitaka could not read its settings file, so it went back to your '
          'settings from 11/20/2026 09:30.',
    ),
    (
      'could not read, started empty',
      const StartupRecovery(
        cause: StartupRecoveryCause.unreadableFile,
        outcome: StartupRecoveryOutcome.startedEmpty,
        folder: _folder,
      ),
      'ePitaka could not read its settings file, so it started with default '
          'settings.',
    ),
  ];

  for (final (label, recovery, text) in rows) {
    testWidgets('after a recovery ($label) the notice shows its text once',
        (tester) async {
      pendingStartupRecovery = recovery;

      await _pumpApp(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(text), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
      expect(pendingStartupRecovery, isNull);
    });
  }

  testWidgets('the notice uses the theme colours, a border and a set width',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pendingStartupRecovery = rows.first.$2;

    await _pumpApp(tester);

    final colors = _theme.colorScheme;
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, colors.surface);
    expect(bar.behavior, isNull);
    expect(bar.width, isNull);
    final shape = bar.shape! as RoundedRectangleBorder;
    expect(shape.side.color, colors.outlineVariant);
    expect(tester.widget<Icon>(find.byIcon(Icons.info_outline)).color,
        colors.primary);
    final text = tester.widget<Text>(find.text(rows.first.$3));
    expect(find.ancestor(of: find.text(rows.first.$3), matching: find.byType(SelectionArea)),
        findsOneWidget);
    expect(text.style?.color, colors.onSurface);
    expect(text.textAlign, TextAlign.center);
    // The icon, the text and Close are one centred group on one line.
    final bar0 = tester.getCenter(find.byType(SnackBar)).dx;
    final left = tester.getTopLeft(find.byIcon(Icons.info_outline)).dx;
    final right = tester.getTopRight(find.widgetWithText(TextButton, 'Close')).dx;
    expect((left + right) / 2, closeTo(bar0, 1));
    expect(tester.getSize(find.text(rows.first.$3)).height, lessThan(30));
  });

  testWidgets('the notice is a bar across the whole window width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pendingStartupRecovery = rows.first.$2;

    await _pumpApp(tester);

    expect(tester.getSize(find.byType(SnackBar)).width, 1200);
  });

  testWidgets('Close hides the notice', (tester) async {
    pendingStartupRecovery = rows.first.$2;
    await _pumpApp(tester);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('with no recovery there is no notice', (tester) async {
    await _pumpApp(tester);

    expect(find.byType(SnackBar), findsNothing);
  });
}

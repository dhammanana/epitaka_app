/// Regression tests for the table of contents "current heading" behavior:
/// when the reader is at (or has jumped to) a specific paragraph, opening the
/// TOC must scroll to the enclosing heading AND highlight it.
///
/// These tests pin the behavior so a future refactor can't silently drop the
/// `currentParaId` wiring (the reader passes it via the `/contents` route
/// query param; [ContentsScreen] / [ContentsPanel] use it to compute the
/// current heading, scroll to it and highlight the row).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/models/app_models.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/contents/providers/contents_provider.dart';
import 'package:epitaka/features/contents/screens/contents_screen.dart';
import 'package:epitaka/features/contents/widgets/contents_panel.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'helpers/type_keys.dart';

/// 20 headings with ascending paraIds — mirrors how `contentsProvider`
/// orders rows (`ORDER BY para_id`), which `_currentHeadingIndex` relies on.
List<HeadingInfo> _headings() => [
  for (var i = 1; i <= 20; i++)
    HeadingInfo(bookId: 'dn1', paraId: i, level: 1, title: 'Heading $i'),
];

/// Target paragraph deep inside the list (Heading 12 has paraId 12).
const _targetParaId = 12;
const _targetTitle = 'Heading 12';

/// Minimal MaterialApp with the app's localization delegates installed
/// (the Contents UI calls [AppLocalizations.of]).
Widget _app(Widget home) {
  return MaterialApp(
    supportedLocales: AppLocalizationsDelegate.supportedLocales,
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

Widget _build(Widget child) {
  return ProviderScope(
    overrides: [
      contentsProvider('dn1').overrideWith((ref) async => _headings()),
      settingsProvider.overrideWith((ref) {
        final notifier = SettingsNotifier(null);
        notifier.state = const AppSettings();
        return notifier;
      }),
    ],
    child: _app(child),
  );
}

void main() {
  group('ContentsScreen — current heading highlight + scroll', () {
    testWidgets('highlights and scrolls to the heading for currentParaId', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          const ContentsScreen(bookId: 'dn1', currentParaId: _targetParaId),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.text(_targetTitle);
      expect(target, findsOneWidget, reason: 'current heading must be built');

      // 1) The heading is actually visible (auto-scrolled into view). If the
      //    scroll-to-current logic is missing, the row stays far below the
      //    viewport and ListView.builder never builds it.
      final rect = tester.getRect(target);
      expect(rect.top, greaterThanOrEqualTo(0), reason: 'heading visible');
      expect(rect.bottom, lessThanOrEqualTo(600), reason: 'heading visible');

      // 2) The current heading is highlighted (primary color + bold).
      final scheme = Theme.of(tester.element(target)).colorScheme;
      final style = tester.widget<Text>(target).style!;
      expect(style.color, scheme.primary, reason: 'current heading color');
      expect(style.fontWeight, FontWeight.w700, reason: 'current heading bold');

      // 3) A nearby NON-current heading keeps the default styling.
      final nonCurrent = find.text('Heading 11');
      if (nonCurrent.evaluate().isNotEmpty) {
        final s = tester.widget<Text>(nonCurrent).style!;
        expect(s.color, scheme.onSurface, reason: 'other heading color');
        expect(s.fontWeight, FontWeight.w400, reason: 'other heading weight');
      }

      // 4) The list really scrolled (offset > 0), not just "lucky" layout.
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ContentsScreen),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        scrollable.position.pixels,
        greaterThan(0),
        reason: 'list auto-scrolled down to the current heading',
      );
    });

    testWidgets('no currentParaId → first heading highlighted, no scroll', (
      tester,
    ) async {
      await tester.pumpWidget(_build(const ContentsScreen(bookId: 'dn1')));
      await tester.pumpAndSettle();

      // Without a current paragraph there is nothing to highlight/scroll to.
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ContentsScreen),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, 0);

      final first = tester.widget<Text>(find.text('Heading 1'));
      final scheme = Theme.of(
        tester.element(find.text('Heading 1')),
      ).colorScheme;
      expect(
        first.style!.color,
        scheme.onSurface,
        reason: 'no heading highlighted',
      );
      expect(first.style!.fontWeight, FontWeight.w400);
    });
  });

  group('ContentsPanel — current heading highlight + scroll', () {
    testWidgets('highlights and scrolls to the heading for currentParaId', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          const Scaffold(
            body: ContentsPanel(bookId: 'dn1', currentParaId: _targetParaId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.text(_targetTitle);
      expect(target, findsOneWidget, reason: 'current heading must be built');

      final rect = tester.getRect(target);
      expect(rect.top, greaterThanOrEqualTo(0), reason: 'heading visible');
      expect(rect.bottom, lessThanOrEqualTo(600), reason: 'heading visible');

      final scheme = Theme.of(tester.element(target)).colorScheme;
      final style = tester.widget<Text>(target).style!;
      expect(style.color, scheme.primary, reason: 'current heading color');
      expect(style.fontWeight, FontWeight.w700, reason: 'current heading bold');

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ContentsPanel),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        scrollable.position.pixels,
        greaterThan(0),
        reason: 'panel auto-scrolled to the current heading',
      );
    });
  });

  group('Contents search — Velthuis and the help icon', () {
    Future<void> typeIn(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      final help = find.descendant(
        of: find.byType(TextField),
        matching: find.byType(VelthuisHelpIcon),
      );
      expect(help, findsOneWidget);
      await typeKeys(tester, find.byType(TextField), 'paali');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'pāli',
      );
      expect(help, findsOneWidget);
    }

    testWidgets('phone screen', (tester) async {
      await tester.pumpWidget(_build(const ContentsScreen(bookId: 'dn1')));
      await typeIn(tester);
    });

    testWidgets('desktop panel', (tester) async {
      await tester.pumpWidget(
        _build(const Scaffold(body: ContentsPanel(bookId: 'dn1'))),
      );
      await typeIn(tester);
    });
  });
}

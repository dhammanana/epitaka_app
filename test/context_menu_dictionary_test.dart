import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/services/reader_copy_service.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the context menu's Dictionary item behaves like the double-tap
/// lookup: it hit-tests the render tree at the toolbar anchor (the position
/// the menu appears at) and opens the dictionary with the exact word under
/// it — rather than relying only on the selection's plain text (which can be
/// empty, in a non-Roman script, or absent on a desktop right-click without
/// a prior selection).
///
/// The harness mirrors the reader wiring: a [Listener] carrying the hit-test
/// key wraps the text, and the [SelectionArea] context menu is built by
/// [ReaderCopyService.buildContextMenu] with that key.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Dictionary context-menu item opens the dictionary with the word '
    'under the menu',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final prefs = await SharedPreferences.getInstance();
      container.read(settingsProvider.notifier).init(prefs);

      // Desktop-width window: wide enough for the toolbar to show every
      // action inline (on a narrow phone screen the toolbar overflows the
      // rest into a … more menu, hiding the Dictionary item).
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final hitTestKey = GlobalKey();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizationsDelegate.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Center(
                child: _ContextMenuHarness(hitTestKey: hitTestKey),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Double-tap the single word to select it — the context menu then
      // appears, anchored over the word (same gesture as the reader's
      // double-tap lookup, but this harness has no word-lookup detector so
      // SelectionArea itself creates the selection + toolbar).
      final textPos = tester.getCenter(find.text('bhagavā'));
      await _doubleTapAt(tester, textPos);
      await tester.pumpAndSettle();

      // The toolbar shows the Dictionary item.
      expect(find.text('Dictionary'), findsOneWidget,
          reason: 'context menu shows the Dictionary item');

      // Tapping Dictionary routes the lookup into the dictionary panel with
      // the word under the menu (the same word the double-tap would find).
      await tester.tap(find.text('Dictionary'));
      await tester.pumpAndSettle();
      // Let ContextMenuButton's 150ms press-state reset timer fire.
      await tester.pump(const Duration(milliseconds: 300));

      final panels = container.read(sidePanelProvider);
      expect(panels.right.openPanel, SidePanelType.dictionary,
          reason: 'dictionary panel opened from the context menu item');
      expect(panels.right.panelData, 'bhagavā',
          reason: 'the word under the menu was looked up, like double-tap');
    },
  );

  testWidgets('sanity: double-tap shows a plain-text context menu', (
    tester,
  ) async {
    // Proves the harness gesture really produces a selection + toolbar —
    // same baseline check as reader_doubletap_clear_test.dart.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Center(
              child: SelectionArea(
                contextMenuBuilder: (context, state) => const Text(
                  'CTX-MENU',
                  textDirection: TextDirection.ltr,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'bhagavā',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final textPos = tester.getCenter(find.text('bhagavā'));
    await _doubleTapAt(tester, textPos);
    await tester.pumpAndSettle();

    expect(find.text('CTX-MENU'), findsOneWidget,
        reason: 'a real double-tap selects the word and shows the menu');
  });
}

/// Two taps at [pos] ~90ms apart, the second held past kPressTimeout (100ms)
/// so the recognizer's delayed onTapDown (word selection) actually fires —
/// the same gesture sequence the reader's own double-tap tests rely on.
Future<void> _doubleTapAt(WidgetTester tester, Offset pos) async {
  final g1 = await tester.startGesture(pos);
  await tester.pump();
  await g1.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 90));
  final g2 = await tester.startGesture(pos);
  await tester.pump(const Duration(milliseconds: 150));
  await g2.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Builds a [SelectionArea] whose context menu is the real reader toolbar
/// ([ReaderCopyService.buildContextMenu]) wired with the hit-test key that
/// the reader attaches to its content [Listener].
class _ContextMenuHarness extends ConsumerWidget {
  const _ContextMenuHarness({required this.hitTestKey});

  final GlobalKey hitTestKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        return ReaderCopyService.buildContextMenu(
          context: context,
          selectableRegionState: selectableRegionState,
          colors: colors,
          lastSelectedContent: null,
          ref: ref,
          visibleStartIndex: 0,
          visibleEndIndex: 0,
          bookId: 'test',
          currentParaId: null,
          currentLineId: null,
          selectedText: null,
          contentHitTestKey: hitTestKey,
        );
      },
      child: Listener(
        key: hitTestKey,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'bhagavā',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}

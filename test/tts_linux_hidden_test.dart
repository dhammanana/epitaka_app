/// On Linux the speech plugin does not exist, so no speech control may show.
/// Saved settings that mention speech stay stored; they are only hidden.
@TestOn('linux')
library;

import 'package:epitaka/core/models/context_menu_action.dart';
import 'package:epitaka/core/models/toolbar_item.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/guide/feature_guide_content.dart';
import 'package:epitaka/features/library/widgets/history_tabs.dart';
import 'package:epitaka/features/reader/services/reader_copy_service.dart';
import 'package:epitaka/features/reader/widgets/reader_bottom_toolbar.dart';
import 'package:epitaka/features/settings/providers/tts_provider.dart';
import 'package:epitaka/features/settings/screens/context_menu_settings_screen.dart';
import 'package:epitaka/features/settings/screens/settings_screen.dart';
import 'package:epitaka/features/settings/screens/toolbar_settings_screen.dart';
import 'package:epitaka/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget app(Widget home, {bool bare = false}) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizationsDelegate.supportedLocales,
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: bare ? home : Scaffold(body: Center(child: home)),
  );

  /// Pumps [child] with real settings loaded from empty preferences.
  Future<ProviderContainer> pumpWithSettings(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
    bool bare = false,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(child, bare: bare),
      ),
    );
    // The settings screen never goes idle (pumpAndSettle times out on it), so
    // pump a fixed time for the localization delegate to load.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  testWidgets('toolbar has no listen button even with a saved listen item', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ReaderBottomToolbar(
          colors: const ColorScheme.light(),
          displayMode: TranslationDisplayMode.lineByLine,
          showTranslation: true,
          ttsPlayback: TtsPlaybackState.stopped,
          items: [
            for (final id in ToolbarBuiltins.defaults) ToolbarItem(id: id),
          ],
          onJumpTap: () {},
          onListenTap: () {},
          onStopTap: () {},
        ),
      ),
    );
    await tester.pump();

    // The jump button proves the toolbar did render.
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsNothing);
  });

  testWidgets('toolbar editor has no listen row but keeps the saved item', (
    tester,
  ) async {
    final container = await pumpWithSettings(
      tester,
      const ToolbarSettingsBody(),
    );

    expect(find.text('Jump'), findsOneWidget);
    expect(find.text('Listen'), findsNothing);
    expect(
      container
          .read(settingsProvider)
          .toolbarItems
          .any((i) => i.id == ToolbarBuiltins.listen),
      isTrue,
    );
  });

  testWidgets('reordering the toolbar editor keeps the hidden listen item', (
    tester,
  ) async {
    final container = await pumpWithSettings(
      tester,
      const ToolbarSettingsBody(),
    );
    List<String> ids() =>
        container.read(settingsProvider).toolbarItems.map((i) => i.id).toList();
    final before = ids();
    final listenAt = before.indexOf(ToolbarBuiltins.listen);

    await tester.drag(
      find.byIcon(Icons.drag_indicator).first,
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();

    final after = ids();
    expect(after, isNot(before), reason: 'the drag must have moved a row');
    expect(after.toSet(), before.toSet());
    expect(after.indexOf(ToolbarBuiltins.listen), listenAt);
  });

  testWidgets('context menu editor has no "speak from here" row', (
    tester,
  ) async {
    final container = await pumpWithSettings(
      tester,
      const ContextMenuSettingsBody(),
    );

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text(ContextMenuBuiltins.speakFromHere), findsNothing);
    expect(find.text('Speak'), findsNothing);
    expect(
      container
          .read(settingsProvider)
          .contextMenuActions
          .any((a) => a.builtinId == ContextMenuBuiltins.speakFromHere),
      isTrue,
    );
  });

  testWidgets('reordering the context menu editor keeps the hidden speech '
      'actions in their slots', (tester) async {
    final container = await pumpWithSettings(
      tester,
      const ContextMenuSettingsBody(),
    );
    List<String> ids() =>
        container.read(settingsProvider).contextMenuActions
            .map((a) => a.id)
            .toList();
    final before = ids();
    final at = {
      for (final id in ['builtin:speak', 'builtin:speakFromHere'])
        id: before.indexOf(id),
    };

    await tester.drag(
      find.byIcon(Icons.drag_indicator).first,
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();

    final after = ids();
    expect(after, isNot(before), reason: 'the drag must have moved a row');
    expect(after.toSet(), before.toSet());
    for (final e in at.entries) {
      expect(after.indexOf(e.key), e.value, reason: e.key);
    }
  });

  testWidgets('selection menu hides speech actions even when saved enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    final settings = container.read(settingsProvider.notifier)..init(prefs);
    await settings.setContextMenuActionEnabled('builtin:speak', true);
    await settings.setContextMenuActionEnabled('builtin:speakFromHere', true);

    final hitTestKey = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(
          Consumer(
            builder: (context, ref, _) => SelectionArea(
              contextMenuBuilder: (context, state) =>
                  ReaderCopyService.buildContextMenu(
                    context: context,
                    selectableRegionState: state,
                    colors: Theme.of(context).colorScheme,
                    lastSelectedContent: null,
                    ref: ref,
                    visibleStartIndex: 0,
                    visibleEndIndex: 0,
                    bookId: 'test',
                    currentParaId: null,
                    currentLineId: null,
                    selectedText: null,
                    contentHitTestKey: hitTestKey,
                  ),
              child: Listener(
                key: hitTestKey,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('bhagavā', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Same two-tap gesture the reader's own menu tests use to select a word.
    final pos = tester.getCenter(find.text('bhagavā'));
    final g1 = await tester.startGesture(pos);
    await tester.pump();
    await g1.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final g2 = await tester.startGesture(pos);
    await tester.pump(const Duration(milliseconds: 150));
    await g2.up();
    await tester.pumpAndSettle();

    expect(find.text('Dictionary'), findsOneWidget, reason: 'menu is open');
    expect(find.text('Speak from here'), findsNothing);
    expect(find.text('Speak'), findsNothing);
  });

  test('context menu speech actions are unavailable', () {
    final all = defaultContextMenuActions();
    for (final id in [
      ContextMenuBuiltins.speakFromHere,
      ContextMenuBuiltins.speak,
    ]) {
      expect(
        all.singleWhere((a) => a.builtinId == id).isAvailableHere,
        isFalse,
        reason: id,
      );
    }
    expect(all.where((a) => a.isAvailableHere), hasLength(all.length - 2));
  });

  testWidgets('settings screen has no speech rows', (tester) async {
    await pumpWithSettings(tester, const SettingsScreen(), bare: true);

    expect(find.text('Context Menu'), findsOneWidget);
    expect(find.text('Text-to-Speech'), findsNothing);
    expect(find.text('TTS Replacements'), findsNothing);
  });

  test('speech settings routes do not exist', () {
    final router = buildRouter();
    addTearDown(router.dispose);

    expect(router.namedLocation('readingOptions'), '/settings/reading');
    expect(() => router.namedLocation('ttsSettings'), throwsA(anything));
    expect(() => router.namedLocation('ttsReplacements'), throwsA(anything));
  });

  testWidgets('history has no Listening tab', (tester) async {
    await pumpWithSettings(
      tester,
      Builder(
        builder: (context) =>
            HistoryTabsSection(colors: Theme.of(context).colorScheme),
      ),
      overrides: [historyProvider.overrideWith((ref) async => [])],
    );

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Listening'), findsNothing);
  });

  test('feature guide mentions no speech', () {
    final texts = [
      for (final s in kFeatureGuideSections)
        for (final step in s.visibleSteps) step.textKey.toLowerCase(),
    ];
    expect(texts, isNotEmpty);
    expect(texts.where((t) => t.contains('text-to-speech')), isEmpty);
  });
}

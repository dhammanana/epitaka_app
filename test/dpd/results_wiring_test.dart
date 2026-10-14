/// The dictionary sheet and the desktop panel draw the new DPD results.
///
/// They read the real fixture database (rows copied from the DPD export), so
/// this covers the whole path: lookup, result view, cards.
library;

import 'dart:io';

import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/models/lookup_results.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart' show preloadDictionaryList;

String _drawn(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_wiring_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> makeContainer(
    WidgetTester tester,
    String word, {
    List<String> alsoLoad = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith((ref) async => dbFile),
        dictionaryBooksProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);
    container.read(dpdSettingsProvider.notifier).setShowSummary(false);
    // Real database work never finishes on the test's fake clock, so the
    // lookup runs first, outside it, and stays cached while the widget reads
    // it. Starting it inside `runAsync` keeps its futures off the fake clock.
    await tester.runAsync(() async {
      await preloadDictionaryList(container);
      for (final w in [word, ...alsoLoad]) {
        container.listen(dpdLookupProvider(w), (_, _) {});
        await container.read(dpdLookupProvider(w).future);
      }
    });
    return container;
  }

  Widget wrap(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.forPreference(
          ThemePreference.light,
          platformBrightness: Brightness.light,
        ),
        locale: const Locale('en'),
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('lookup provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [dpdDatabaseFileProvider.overrideWith((ref) async => dbFile)],
      );
    });

    tearDown(() => container.dispose());

    test('a mistyped word is rescued by the folded key', () async {
      final lookup = await container.read(dpdLookupProvider('kammam').future);
      expect(lookup.headwords, isNotEmpty);
      // The other dictionaries are searched with the headword's own lemma.
      expect(lookup.searchWord, 'kamma');
    });

    // `kāya` is also a form of `ka`, which sorts first, so the other
    // dictionaries were searched for `ka`. The word the user typed leads when
    // it is a headword of its own (real rows of the fixture: `vā` and `va`).
    test('a typed word that is a headword is searched as itself', () async {
      for (final word in ['vā', 'so', 'taṃ', 'kāmaṃ']) {
        final lookup = await container.read(dpdLookupProvider(word).future);
        expect(lookup.searchWord, word, reason: word);
      }
    });

    test('the typed word leads however it is cased', () async {
      final lookup = await container.read(dpdLookupProvider('Vā').future);
      expect(lookup.searchWord, 'vā');
    });

    // The lookup drops hyphens and apostrophes from what was typed, so the
    // comparison has to as well.
    test('the typed word leads with a hyphen or an apostrophe in it', () async {
      for (final typed in ['v-ā', "v'ā"]) {
        final lookup = await container.read(dpdLookupProvider(typed).future);
        expect(lookup.searchWord, 'vā', reason: typed);
      }
    });

    // `kkamaṃ` has only a deconstruction, and its folded key `kamam` is shared
    // by four headwords. They are not what the user looked up.
    test('a word with a deconstruction is not folded into strangers', () async {
      final lookup = await container.read(dpdLookupProvider('kkamaṃ').future);
      expect(lookup.secondary.whereType<DeconstructorResult>(), isNotEmpty);
      expect(lookup.headwords, isEmpty);
      expect(lookup.searchWord, 'kkamaṃ');
    });

    test('a word with no entry has no match', () async {
      final lookup = await container.read(dpdLookupProvider('zzzqx').future);
      expect(lookup.hasMatch, isFalse);
      expect(lookup.searchWord, 'zzzqx');
    });

    test('a root and a deconstruction come from the lookup row', () async {
      final root = await container.read(dpdLookupProvider('anugā').future);
      expect(root.roots.map((r) => r.root.root), ['√gā']);
      final decon = await container.read(dpdLookupProvider('abba').future);
      expect(decon.secondary.whereType<DeconstructorResult>(), isNotEmpty);
    });
  });

  testWidgets('the sheet draws the headword lemma and its meaning', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeContainer(tester, 'dhamma');

    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settle(tester);

    final text = _drawn(tester);
    expect(text, contains('dhamma 1.01'));
    expect(text, contains('nature; character'));
  });

  testWidgets('the desktop panel draws the same', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeContainer(tester, 'dhamma');

    await tester.pumpWidget(
      wrap(container, const DictionaryPanel(initialWord: 'dhamma')),
    );
    await settle(tester);

    final text = _drawn(tester);
    expect(text, contains('dhamma 1.01'));
    expect(text, contains('nature; character'));
  });

  testWidgets('a word with a deconstruction shows the deconstructor card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeContainer(tester, 'abba');

    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'abba')),
    );
    await settle(tester);

    expect(_drawn(tester), contains('deconstructor: abba'));
  });

  testWidgets('a root draws as a root summary', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeContainer(tester, 'anugā');

    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'anugā')),
    );
    await settle(tester);

    expect(_drawn(tester), contains('root: gā'));
  });

  /// The screen position of the character at [index] in the paragraph that
  /// draws [paragraphText], found through the render tree.
  Offset pointInParagraph(
    WidgetTester tester,
    String paragraphText,
    int index,
  ) {
    RenderParagraph? found;
    void visit(RenderObject node) {
      if (found == null &&
          node is RenderParagraph &&
          node.text.toPlainText().contains(paragraphText)) {
        found = node;
        return;
      }
      node.visitChildren(visit);
    }

    visit(tester.binding.renderViews.first);
    final paragraph = found!;
    final at = paragraph.text.toPlainText().indexOf(paragraphText) + index;
    final caret = paragraph.getOffsetForCaret(
      TextPosition(offset: at),
      Rect.zero,
    );
    final height = paragraph.getFullHeightForCaret(TextPosition(offset: at));
    return paragraph.localToGlobal(caret + Offset(2, height / 2));
  }

  testWidgets('tapping a word inside an entry looks that word up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeContainer(
      tester,
      'dhamma',
      alsoLoad: ['nature'],
    );

    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settle(tester);

    // Tap inside "nature" of the summary line "nature; character".
    await tester.tapAt(pointInParagraph(tester, 'nature; character', 2));
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'nature');
  });

  testWidgets('tapping a section button does not look a word up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeContainer(tester, 'dhamma');

    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settle(tester);

    await tester.tap(find.text('grammar').first);
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'dhamma');
    expect(find.text('Lemma'), findsWidgets);
  });

  testWidgets('with the double-tap setting, a single tap looks nothing up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeContainer(
      tester,
      'dhamma',
      alsoLoad: ['nature'],
    );
    container
        .read(settingsProvider.notifier)
        .setWordLookupGesture(WordLookupGesture.doubleTap);

    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settle(tester);

    await tester.tapAt(pointInParagraph(tester, 'nature; character', 2));
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'dhamma');
  });

  testWidgets('a release after the entry was replaced does not throw', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeContainer(tester, 'dhamma');

    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settle(tester);

    final gesture = await tester.startGesture(
      pointInParagraph(tester, 'nature; character', 2),
    );
    // The whole sheet goes away while the finger is down.
    await tester.pumpWidget(wrap(container, const SizedBox()));
    await gesture.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

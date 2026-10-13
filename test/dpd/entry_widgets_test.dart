import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart'
    show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/widgets/inline_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';

String _drawn(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

void main() {
  late Directory dir;
  late DpdDatabase db;
  late DpdHeadwordWithRoot headword;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_entry_widgets_test');
    db = DpdDatabase(buildDpdFixture(dir));
    headword = (await DpdDao(db).searchExact('dhamma')).first;
  });

  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> pumpCard(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    // Load the settings first, so the card reads them in initState and not
    // through the change listener.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(dpdSettingsProvider);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forPreference(
            ThemePreference.light,
            platformBrightness: Brightness.light,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: InlineEntryCard(
                headword: headword,
                level: DictionaryLevel.majjhima,
                lookupKey: 'dhamma',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the lemma, the summary and a closed grammar button', (
    tester,
  ) async {
    await pumpCard(tester, {});
    final text = _drawn(tester);
    expect(text, contains('dhamma 1.01'));
    expect(text, contains('nature; character'));
    expect(find.text('grammar'), findsOneWidget);
    expect(text, isNot(contains('Lemma')));
  });

  testWidgets('tapping the grammar button opens the grammar table', (
    tester,
  ) async {
    await pumpCard(tester, {});
    await tester.tap(find.text('grammar'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Lemma'), findsOneWidget);
  });

  testWidgets('the grammar-open setting opens the table at once', (
    tester,
  ) async {
    await pumpCard(tester, {'dpd_grammar_open': true});
    expect(find.text('Lemma'), findsOneWidget);
  });
}

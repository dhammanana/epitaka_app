import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_search_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the DPD dictionary render path against the expensive
/// clickable-word transformation.
///
/// DPD entries used to have every Pāli word in `meaning_html` wrapped in
/// `<a href="lookup://…">` anchors (two regex passes over the whole HTML
/// string per headword), which dominated the cost of the first dictionary
/// load on desktop. It was removed so DPD renders exactly like the other
/// dictionaries: the raw HTML is passed through unchanged.
///
/// These tests pin that behavior — if the transform ever comes back, the
/// `Html.data` assertions fail.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'DpdHtmlRichText passes the raw meaning HTML through unchanged — '
    'no clickable lookup:// anchors are injected',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final prefs = await SharedPreferences.getInstance();
      container.read(settingsProvider.notifier).init(prefs);

      const rawHtml =
          '<summary>free from desire</summary>'
          '<p>One who has destroyed the <b>cankers</b> (āsava) and is '
          '<i>without desire</i>. dhamma and kamma are words.</p>'
          '<details><summary>Grammar</summary><p>khīṇa + āsa + va</p>'
          '</details>';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DpdHtmlRichText(
                html: rawHtml,
                baseStyle: const TextStyle(fontSize: 14),
                linkColor: Colors.blue,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The exact raw HTML reaches flutter_html unmodified — the same
      // behavior as the other dictionaries' definitions (DictHtmlContent).
      final htmlWidgets = tester
          .widgetList<Html>(find.byType(Html))
          .toList();
      expect(htmlWidgets, isNotEmpty, reason: 'flutter_html rendered the entry');
      final data = htmlWidgets.first.data ?? '';
      expect(data, rawHtml, reason: 'raw HTML is not rewritten');
      expect(data.contains('lookup://'), isFalse,
          reason: 'no clickable-word anchors were injected');

      // The content is actually visible.
      expect(find.textContaining('cankers'), findsOneWidget);
    },
  );

  testWidgets('DpdHeadwordCard renders lemma and meaning without onWordTap', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);

    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: DpdHeadwordCard(
              lemma: 'khīṇāsava',
              meaningHtml:
                  '<p>One who has destroyed the cankers. '
                  'See <a href="lookup://khina">khīṇa</a>.</p>',
              colors: ThemeData().colorScheme,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Lemma + meaning render as normal text.
    expect(find.text('khīṇāsava'), findsOneWidget);
    expect(find.textContaining('destroyed the cankers'), findsOneWidget);
  });
}

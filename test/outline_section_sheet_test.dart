/// Tests for the outline section quickview sheet's Study guide tab.
///
/// The tab must only appear once a study guide has actually resolved —
/// sections without a summary just get the Text tab, so no spinner ever
/// hangs on a missing guide (previously the tab was always shown and its
/// lazy FutureBuilder spun on the network fallback before giving up).
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/database/epitaka_database.dart';
import '../lib/core/providers/database_provider.dart';
import '../lib/core/providers/settings_provider.dart';
import '../lib/core/utils/app_localizations.dart';
import '../lib/features/outline/models/outline_models.dart';
import '../lib/features/outline/services/study_guide_fetcher.dart';
import '../lib/features/outline/widgets/outline_section_sheet.dart';

Future<EpitakaDatabase> _seedDatabase() async {
  final db = EpitakaDatabase(NativeDatabase.memory());

  await db.customStatement(
    'CREATE TABLE headings ('
    'book_id TEXT NOT NULL, para_id INTEGER NOT NULL, level INTEGER, '
    'title TEXT, chapter_len INTEGER, parent INTEGER, sc_id TEXT, '
    'PRIMARY KEY (book_id, para_id))',
  );
  await db.customStatement(
    'CREATE TABLE sentences ('
    'book_id TEXT NOT NULL, para_id INTEGER NOT NULL, line_id INTEGER NOT NULL, '
    'vripara TEXT, thaipage TEXT, vripage TEXT, ptspage TEXT, mypage TEXT, '
    'pali TEXT, PRIMARY KEY (book_id, para_id, line_id))',
  );

  await db.customStatement(
    "INSERT INTO headings(book_id, para_id, level, title, parent) "
    "VALUES ('M-i', 6, 10, 'One', 5)",
  );
  await db.customStatement(
    "INSERT INTO sentences(book_id, para_id, line_id, pali) "
    "VALUES ('M-i', 6, 1, 'pali line')",
  );
  return db;
}

void main() {
  late EpitakaDatabase db;

  setUp(() async {
    db = await _seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Pump a host screen with a button that opens the section sheet for
  /// section [sectionId]. [guideLoader] drives [studyGuideProvider].
  Future<void> pumpSheet(
    WidgetTester tester, {
    required Future<StudyGuide?> Function(StudyGuideQuery query) guideLoader,
    int sectionId = 6,
  }) async {
    final container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => db),
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(null);
          notifier.state = const AppSettings(showTranslation: false);
          return notifier;
        }),
        studyGuideProvider.overrideWith((ref, query) => guideLoader(query)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      // ignore: avoid_print
                      print('DBG onPressed fired');
                      showOutlineSectionSheet(
                        context,
                        ref,
                        bookId: 'M-i',
                        bookName: 'Mūlapaṇṇāsapāḷi',
                        item: OutlineItem(
                          paraId: sectionId,
                          sectionEnd: sectionId,
                          title: 'One',
                          level: 10,
                        ),
                      ).catchError((Object e) {
                        // ignore: avoid_print
                        print('DBG showOutlineSectionSheet error: $e');
                      });
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    // ignore: avoid_print
    print('DBG ElevatedButton: ${find.byType(ElevatedButton).evaluate().length}');
    // ignore: avoid_print
    print('DBG text open: ${find.text('open').evaluate().length}');
    // ignore: avoid_print
    print('DBG ErrorWidget: ${find.byType(ErrorWidget).evaluate().length}');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('DBG BottomSheet: ${find.byType(BottomSheet).evaluate().length}');
    // ignore: avoid_print
    print('DBG SegmentedButton: ${find.byType(SegmentedButton<int>).evaluate().length}');
    // ignore: avoid_print
    print('DBG TextTab: ${find.text('Text').evaluate().length}');
    // ignore: avoid_print
    print('DBG SnackBar: ${find.byType(SnackBar).evaluate().length}');
  }

  testWidgets('shows the Study guide tab only when a guide exists',
      (tester) async {
    await pumpSheet(
      tester,
      guideLoader: (query) async => query.sectionId == 6
          ? const StudyGuide(
              title: 'The Discourse on the Root of All Phenomena',
              contentMd: 'A short study guide.',
            )
          : null,
    );

    // Section 6 has a guide → the tab appears and the Text tab is there too.
    expect(find.text('Study guide'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);

    // Opening it shows the content immediately — no spinner, no
    // "unavailable" message.
    await tester.tap(find.text('Study guide'));
    await tester.pumpAndSettle();
    expect(
      find.text('The Discourse on the Root of All Phenomena'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Study guide not available.'), findsNothing);
  });

  testWidgets('hides the Study guide tab when no summary exists',
      (tester) async {
    await pumpSheet(tester, guideLoader: (query) async => null);

    // No summary → only the Text tab is offered.
    expect(find.text('Study guide'), findsNothing);
    expect(find.text('Text'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('does not offer the tab while the guide is still loading',
      (tester) async {
    final completer = Completer<StudyGuide?>();
    await pumpSheet(tester, guideLoader: (query) => completer.future);

    // Still resolving → the tab must not appear yet (no spinner to hang on).
    expect(find.text('Study guide'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Once it resolves to a guide, the tab appears.
    completer.complete(
      const StudyGuide(title: 'Late Guide', contentMd: 'content'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Study guide'), findsOneWidget);

    await tester.tap(find.text('Study guide'));
    await tester.pumpAndSettle();
    expect(find.text('Late Guide'), findsOneWidget);
  });
}

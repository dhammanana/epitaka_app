/// The translation-remark editor dialog must show EVERY field a
/// `translation_remarks` row carries (Pāli, translation, conflict, note,
/// source, created), not just the free-text note, and saving must write the
/// edits back to the translation database (update / insert / delete).
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart'
    show TranslationRemark;
import 'package:epitaka/features/reader/widgets/translation_remark_dialog.dart';
import 'package:epitaka/features/translator/services/translator_engine.dart'
    show ensureTranslatorTables;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TranslationDatabase db;

  setUp(() async {
    db = TranslationDatabase(NativeDatabase.memory());
    await ensureTranslatorTables(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedRemark() async {
    await db.customInsert(
      'INSERT INTO translation_remarks '
      '(book_id, para_id, line_id, pali, translation, conflict, note, source_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('dn1'),
        Variable.withInt(5),
        Variable.withInt(2),
        Variable.withString('citta'),
        Variable.withString('mind'),
        Variable.withString('Abhidhamma vs sutta usage'),
        Variable.withString('Here it refers to the heart-mind.'),
        Variable.withString('translator-v1'),
      ],
    );
  }

  Future<int> rowCount() async {
    final rows = await db.customSelect(
      'SELECT COUNT(*) AS n FROM translation_remarks',
    ).get();
    return rows.first.data['n'] as int;
  }

  Widget wrap({required Widget child}) => ProviderScope(
        overrides: [
          translationDbProvider('en').overrideWith((ref) async => db),
          settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  Future<void> pumpDialog(
    WidgetTester tester, {
    List<TranslationRemark>? initial,
  }) async {
    await tester.pumpWidget(
      wrap(
        child: TranslationRemarkDialog(
          bookId: 'dn1',
          langCode: 'en',
          paraId: 5,
          lineId: 2,
          initialRemarks: initial,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dialog shows every remark field, not just the note', (
    tester,
  ) async {
    await seedRemark();
    await pumpDialog(tester);

    // Dialog title + line context + language chip.
    expect(find.text('Translation remark'), findsOneWidget);
    expect(find.textContaining('Paragraph 5'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);

    // Every editable field is present with its stored value.
    expect(find.widgetWithText(TextField, 'citta'), findsOneWidget,
        reason: 'the Pāli field must show the stored pali');
    expect(find.widgetWithText(TextField, 'mind'), findsOneWidget,
        reason: 'the translation field must show the stored translation');
    expect(
      find.widgetWithText(
        TextField,
        'Abhidhamma vs sutta usage',
      ),
      findsOneWidget,
      reason: 'the conflict field must show the stored conflict',
    );
    expect(
      find.widgetWithText(TextField, 'Here it refers to the heart-mind.'),
      findsOneWidget,
      reason: 'the note field must show the stored note',
    );
    // Source / created metadata renders read-only.
    expect(find.textContaining('translator-v1'), findsOneWidget);
  });

  testWidgets('editing a field and saving updates the row in the DB', (
    tester,
  ) async {
    await seedRemark();
    await pumpDialog(tester);

    // Edit the note field.
    final noteField = find.widgetWithText(
      TextField,
      'Here it refers to the heart-mind.',
    );
    await tester.enterText(noteField, 'Edited note after review.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'the dialog closes after a successful save');
    expect(await rowCount(), 1);

    final rows = await db.customSelect(
      'SELECT note, conflict FROM translation_remarks',
    ).get();
    expect(rows.single.data['note'], 'Edited note after review.');
    expect(rows.single.data['conflict'], 'Abhidhamma vs sutta usage',
        reason: 'unchanged fields are preserved on update');
  });

  testWidgets('adding a remark inserts a new row on save', (tester) async {
    await seedRemark();
    await pumpDialog(tester);

    await tester.tap(find.text('Add remark'));
    await tester.pumpAndSettle();
    // New (empty) row — fill its note field.
    final newNote = find.widgetWithText(TextField, '');
    await tester.enterText(newNote.last, 'A second remark for this line.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await rowCount(), 2);
    final notes = await db.customSelect(
      'SELECT note FROM translation_remarks ORDER BY id',
    ).get();
    expect(notes.map((r) => r.data['note']), contains('A second remark for this line.'));
  });

  testWidgets('without remarks the dialog shows an empty editor and can add', (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text('Translation remark'), findsOneWidget);
    await tester.tap(find.text('Add remark'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'A brand new remark.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await rowCount(), 1);
    final rows = await db.customSelect('SELECT * FROM translation_remarks').get();
    expect(rows.single.data['para_id'], 5);
    expect(rows.single.data['line_id'], 2);
    expect(rows.single.data['book_id'], 'dn1');
    expect(rows.single.data['note'], 'A brand new remark.');
  });
}

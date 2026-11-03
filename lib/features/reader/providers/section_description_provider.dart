import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/translation_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';

/// A heading's explanation, read from the enabled translation database.
class SectionDescription {
  /// The short description — what the section is about, in a sentence.
  final String title;

  /// The summary — the fuller explanation of the section.
  final String text;

  const SectionDescription({required this.title, required this.text});
}

/// The translation language whose database is asked for descriptions: the
/// first enabled translation, or the primary one when translation is shown.
///
/// Null means no translation is displayed, so no description can be offered
/// beside a heading.
final sectionDescriptionLangProvider = Provider<String?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.enabledTranslations.isNotEmpty) {
    return settings.enabledTranslations.first;
  }
  return settings.showTranslation ? settings.primaryTranslationLang : null;
});

/// Languages whose database is known to carry the `descriptions` table.
///
/// The translation databases are built one at a time; only those built with
/// the table can explain a section. Cached, because the probe would otherwise
/// run for every heading on screen on every rebuild.
final _langsWithDescriptions = <String>{};

/// Whether [db] of [lang] has the `descriptions` table.
Future<bool> hasDescriptionsTable(TranslationDatabase db, String lang) async {
  if (_langsWithDescriptions.contains(lang)) return true;
  try {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='descriptions'",
        )
        .get();
    if (rows.isEmpty) return false;
    _langsWithDescriptions.add(lang);
    return true;
  } catch (_) {
    return false;
  }
}

/// The description of one heading, or null when [query]'s language has none
/// for it.
///
/// Keyed by language, book and paragraph, so scrolling past a heading and back
/// does not query the database again.
final sectionDescriptionProvider = FutureProvider.autoDispose
    .family<SectionDescription?, ({String lang, String bookId, int paraId})>((
      ref,
      query,
    ) async {
      final db = await ref.watch(translationDbProvider(query.lang).future);
      if (db == null) return null;
      if (!await hasDescriptionsTable(db, query.lang)) return null;
      try {
        var rows = await db
            .customSelect(
              'SELECT description, summary FROM descriptions '
              'WHERE book_id = ? AND para_id = ? AND lang = ? LIMIT 1',
              variables: [
                Variable.withString(query.bookId),
                Variable.withInt(query.paraId),
                Variable.withString(query.lang),
              ],
            )
            .get();
        if (rows.isEmpty) {
          // A build may leave `lang` empty; the book and paragraph already
          // identify the section, so one row of it is still the right one.
          rows = await db
              .customSelect(
                'SELECT description, summary FROM descriptions '
                'WHERE book_id = ? AND para_id = ? LIMIT 1',
                variables: [
                  Variable.withString(query.bookId),
                  Variable.withInt(query.paraId),
                ],
              )
              .get();
        }
        if (rows.isEmpty) return null;

        final description =
            (rows.first.data['description'] as String?)?.trim() ?? '';
        final summary = (rows.first.data['summary'] as String?)?.trim() ?? '';
        if (description.isEmpty && summary.isEmpty) return null;

        return SectionDescription(
          title: description.isNotEmpty
              ? description
              : summary.split('\n').first.trim(),
          text: summary.isNotEmpty ? summary : description,
        );
      } catch (_) {
        return null;
      }
    });

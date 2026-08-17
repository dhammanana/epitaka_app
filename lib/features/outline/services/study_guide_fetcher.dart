/// Fetches the AI study guide (markdown) for a section.
///
/// Study guides are stored inside the English translation database
/// (`epitaka_en.db`, `summaries` table) — the same DB the app already
/// downloads for English reading / AI Q&A — so the app reads them locally
/// and offline. When the local DB is missing, predates the summaries table,
/// or has no guide for this section, it falls back to the epitaka.org
/// network endpoint. Every failure returns null so callers degrade
/// gracefully to the plain excerpt.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/providers/database_provider.dart';

/// Production API origin (network fallback only). Override for local
/// testing, e.g. `flutter run --dart-define=EPITAKA_BASE_URL=http://127.0.0.1:8083`.
const String kEpitakaWebBaseUrl = String.fromEnvironment(
  'EPITAKA_BASE_URL',
  defaultValue: 'https://epitaka.org',
);

class StudyGuide {
  final String title;
  final String contentMd;

  const StudyGuide({required this.title, required this.contentMd});
}

/// Query parameters for looking up a study guide by book + section.
class StudyGuideQuery {
  final String bookId;
  final int sectionId;

  const StudyGuideQuery({required this.bookId, required this.sectionId});

  @override
  bool operator ==(Object other) =>
      other is StudyGuideQuery &&
      bookId == other.bookId &&
      sectionId == other.sectionId;

  @override
  int get hashCode => Object.hash(bookId, sectionId);
}

/// One study guide for [query]: read from the local English translation DB
/// first (offline), then from epitaka.org when the local DB predates the
/// summaries table.
final studyGuideProvider =
    FutureProvider.family<StudyGuide?, StudyGuideQuery>((ref, query) async {
  final local = await _readLocalStudyGuide(ref, query);
  if (local != null) return local;
  return fetchStudyGuideFromWeb(
    bookId: query.bookId,
    sectionId: query.sectionId,
  );
});

Future<StudyGuide?> _readLocalStudyGuide(
  Ref ref,
  StudyGuideQuery query,
) async {
  try {
    final enDb = await ref.read(translationDbProvider('en').future);
    if (enDb == null) return null;
    final rows = await enDb.customSelect(
      'SELECT title, content FROM summaries '
      'WHERE book_id = ? AND section_id = ?',
      variables: [Variable(query.bookId), Variable(query.sectionId)],
    ).get();
    if (rows.isEmpty) return null;
    // Both columns are NOT NULL in the summaries schema.
    final contentMd = rows.first.read<String>('content');
    if (contentMd.trim().isEmpty) return null;
    return StudyGuide(
      title: rows.first.read<String>('title'),
      contentMd: contentMd,
    );
  } catch (_) {
    // Table missing on an older downloaded DB, or any read error — fall
    // back to the network endpoint.
    return null;
  }
}

/// Network fallback: fetches from epitaka.org's /api/study endpoint.
Future<StudyGuide?> fetchStudyGuideFromWeb({
  required String bookId,
  required int sectionId,
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    final uri = Uri.parse('$kEpitakaWebBaseUrl/api/study/$bookId/$sectionId');
    final res = await http.get(uri).timeout(timeout);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final contentMd = data['content_md'] as String? ?? '';
    if (contentMd.trim().isEmpty) return null;
    return StudyGuide(
      title: data['title'] as String? ?? '',
      contentMd: contentMd,
    );
  } catch (_) {
    return null;
  }
}

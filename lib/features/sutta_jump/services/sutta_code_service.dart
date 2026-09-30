import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/epitaka_database.dart';

/// Where a sutta code opens: a paragraph in a book, plus what to show.
class SuttaTarget {
  final String bookId;
  final int paraId;
  final String displayCode;
  final String title;

  /// The DPD range this sutta sits in (`AN1.1-10` for `AN1.5`), or empty.
  final String rangeCode;

  /// The same sutta's SuttaCentral code when it differs (`THIG2.10` for
  /// `THI28`), or empty.
  final String altCode;

  const SuttaTarget({
    required this.bookId,
    required this.paraId,
    required this.displayCode,
    required this.title,
    this.rangeCode = '',
    this.altCode = '',
  });

  /// `THI28 = THIG2.10`, `AN1.5 (AN1.1-10)` or just `MN10`.
  String get label {
    if (rangeCode.isNotEmpty) return '$displayCode ($rangeCode)';
    if (altCode.isNotEmpty) return '$displayCode = $altCode';
    return displayCode;
  }

  String get _identity => '$bookId|$paraId|$displayCode';
}

const suttaCodesAsset = 'assets/sutta_codes.tsv';
const _maxResults = 20;

/// Parses `assets/sutta_codes.tsv`. The generator writes the lines in
/// natural order (`an1…` before `an10…`) and resolves every precedence rule,
/// so the map keeps file order and a key has exactly one target.
Map<String, SuttaTarget> parseSuttaCodes(String tsv) {
  final map = <String, SuttaTarget>{};
  // LineSplitter also drops a '\r': a CRLF checkout (Windows CI) would
  // otherwise leave one in the last column, and an empty alt_code would
  // read as '\r'.
  for (final line in const LineSplitter().convert(tsv)) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final cols = line.split('\t');
    if (cols.length < 5) continue;
    final paraId = int.tryParse(cols[2]);
    if (paraId == null) continue;
    map[cols[0]] = SuttaTarget(
      bookId: cols[1],
      paraId: paraId,
      displayCode: cols[3],
      title: cols[4],
      rangeCode: cols.length > 5 ? cols[5] : '',
      altCode: cols.length > 6 ? cols[6] : '',
    );
  }
  return map;
}

/// Case and spaces do not matter, and en/em dashes count as `-`, so
/// `MN 10`, `mn10` and `Mn10` are one code.
String normaliseCode(String input) => input
    .replaceAll(RegExp(r'\s+'), '')
    .toLowerCase()
    .replaceAll('–', '-')
    .replaceAll('—', '-');

/// The exact match first, then every code starting with [input] in map
/// order, one entry per distinct target, at most 20. Single suttas inside a
/// range only show as the exact match; listing them all would push the
/// next ranges (`an10…` after `an1…`) out of the 20.
List<SuttaTarget> lookupSuttaCodes(Map<String, SuttaTarget> codes, String input) {
  final code = normaliseCode(input);
  if (code.isEmpty) return const [];
  final seen = <String>{};
  final results = <SuttaTarget>[];
  void add(SuttaTarget target) {
    if (seen.add(target._identity)) results.add(target);
  }

  final exact = codes[code];
  if (exact != null) add(exact);
  for (final entry in codes.entries) {
    if (results.length >= _maxResults) break;
    if (entry.value.rangeCode.isNotEmpty) continue;
    if (entry.key.startsWith(code)) add(entry.value);
  }
  return results;
}

/// Codes the DPD sheet does not cover (Vinaya, Abhidhamma, Milindapañha)
/// still carry SuttaCentral ids on ePitaka's own headings.
Future<List<SuttaTarget>> headingFallback(
  EpitakaDatabase db,
  String input,
) async {
  final code = normaliseCode(input);
  if (code.isEmpty) return const [];
  // Typed '%' and '_' must match themselves, not any text.
  final pattern = code.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
  final rows = await db.customSelect(
    'SELECT book_id, MIN(para_id) AS para_id, title, sc_id FROM headings '
    "WHERE level < 10 AND sc_id LIKE ? || '%' ESCAPE '\\' "
    'GROUP BY book_id, lower(sc_id) '
    'ORDER BY lower(sc_id) = ? DESC, MIN(rowid) '
    'LIMIT $_maxResults',
    variables: [Variable.withString(pattern), Variable.withString(code)],
  ).get();
  return [
    for (final row in rows)
      SuttaTarget(
        bookId: row.read<String>('book_id'),
        paraId: row.read<int>('para_id'),
        displayCode: row.read<String>('sc_id'),
        title: row.read<String?>('title') ?? '',
      ),
  ];
}

final suttaCodesProvider = FutureProvider<Map<String, SuttaTarget>>((ref) async {
  return parseSuttaCodes(await rootBundle.loadString(suttaCodesAsset));
});

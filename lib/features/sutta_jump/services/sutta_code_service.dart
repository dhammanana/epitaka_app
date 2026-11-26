import 'package:drift/drift.dart' show QueryRow, Variable;

import '../../../core/database/epitaka_database.dart';
import '../../search/services/regex_search.dart';
import '../../../core/utils/fuzzy_matcher/fuzzy_matcher_library.dart'
    show normalizeQuery;

/// Where a sutta code opens: a paragraph in a book, plus what to show.
class SuttaTarget {
  final String bookId;
  final int paraId;
  final String displayCode;
  final String title;

  const SuttaTarget({
    required this.bookId,
    required this.paraId,
    required this.displayCode,
    required this.title,
  });

  /// `THI28 = THIG2.10`, `AN1.5 (AN1.1-10)` or just `MN10`.
  String get label => displayCode;

  String get _identity => '$bookId|$paraId|$displayCode';
}

const _maxResults = 20;

/// One entry of a `headings.sc_id` token cell (see
/// scripts/import_sutta_codes.py for the grammar).
///
/// - plain (`mn10`, `an1.1-10`): an exact, range or alias code.
/// - `>an1.102`: a single sutta inside a split DPD range. Resolves only
///   as an exact match and shows `AN1.102 (AN1.1-10)`.
/// - `+an1.188`: a kept-range member with no row of its own. Listed, but
///   shows the covering range (`AN1.188-267`).
/// - `=thig2.10`: a SuttaCentral alias. Shows `THI28 = THIG2.10`.
/// - `an5.303-1151=an5.303`: a DPD range dash carrying its SuttaCentral
///   alt as a suffix payload. Shows `AN5.303-1151 = AN5.303`.
class SuttaToken {
  /// The code to match on, without markers or payload.
  final String key;

  /// One of '', '>', '+', '='.
  final String marker;

  /// The `=alt` suffix payload (only on unmarked DPD range dashes).
  final String payload;

  const SuttaToken({required this.key, required this.marker, this.payload = ''});

  bool get isMember => marker == '>';
  bool get isRangeAlias => marker == '=';
  bool get isKept => marker == '+';
  bool get isPlain => marker.isEmpty;
  bool get isDash => key.contains('-');
}

SuttaToken parseToken(String raw) {
  var marker = '';
  var rest = raw;
  if (rest.startsWith('>') || rest.startsWith('+') || rest.startsWith('=')) {
    marker = rest[0];
    rest = rest.substring(1);
  }
  var payload = '';
  if (marker.isEmpty) {
    final eq = rest.indexOf('=');
    if (eq >= 0) {
      payload = rest.substring(eq + 1);
      rest = rest.substring(0, eq);
    }
  }
  return SuttaToken(key: rest, marker: marker, payload: payload);
}

/// One headings row in canonical (rowid) order with its parsed token cell.
class SuttaLookupRow {
  final String bookId;
  final int paraId;
  final String title;
  final List<SuttaToken> tokens;

  const SuttaLookupRow({
    required this.bookId,
    required this.paraId,
    required this.title,
    required this.tokens,
  });
}

/// Everything "Go to sutta" needs, loaded once per dialog opening so every
/// keystroke filters in memory instead of hitting the database.
class SuttaLookupCache {
  final List<SuttaLookupRow> rows;
  final Map<String, String> bookNames;

  const SuttaLookupCache({required this.rows, required this.bookNames});
}

/// Case and spaces do not matter, and en/em dashes count as `-`, so
/// `MN 10`, `mn10` and `Mn10` are one code.
String normaliseCode(String input) => input
    .replaceAll(RegExp(r'\s+'), '')
    .toLowerCase()
    .replaceAll('–', '-')
    .replaceAll('—', '-');

final _rangeNumber = RegExp(r'^(.*?)(\d+)$');

/// Numeric bounds of a range token (`an1.1-10` -> stem `an1.`, 1, 10), or
/// null when it is not a numeric range.
({String stem, int first, int last})? _parseRange(String token) {
  final dash = token.indexOf('-');
  if (dash < 0) return null;
  final left = _rangeNumber.firstMatch(token.substring(0, dash));
  final right = int.tryParse(token.substring(dash + 1));
  if (left == null || right == null) return null;
  return (
    stem: left.group(1)!,
    first: int.parse(left.group(2)!),
    last: right,
  );
}

/// Whether range token [range] covers [key]: the range itself, its first
/// member (`an1.188` in `an1.188-267`), or a member by number (`an1.10`
/// in `an1.1-10`, but never `an1`).
bool _covers(String range, String key) {
  if (range == key) return true;
  final parsed = _parseRange(range);
  if (parsed == null) return false;
  final match = RegExp('^${RegExp.escape(parsed.stem)}(\\d+)\$')
      .firstMatch(key);
  if (match == null) return false;
  final n = int.parse(match.group(1)!);
  return parsed.first <= n && n <= parsed.last;
}

/// True DPD ranges in [tokens]: unmarked dashes (payload dashes count —
/// they are DPD ranges; `=` alias dashes never cover anything).
Iterable<String> _dpdRanges(Iterable<SuttaToken> tokens) sync* {
  for (final token in tokens) {
    if (token.marker.isEmpty && token.isDash) yield token.key;
  }
}

/// The widest range covering [key] — sheet order puts outer ranges first,
/// so the widest covering range is the member's own row.
String? _widestCovering(Iterable<String> ranges, String key) {
  String? best;
  var bestSpan = -1;
  for (final range in ranges) {
    if (!_covers(range, key)) continue;
    final parsed = _parseRange(range)!;
    final span = parsed.last - parsed.first;
    if (span > bestSpan) {
      best = range;
      bestSpan = span;
    }
  }
  return best;
}

String? _coveringRangeInCell(List<SuttaToken> tokens, String key) =>
    _widestCovering(_dpdRanges(tokens), key);

String? _coveringRangeInBook(
  SuttaLookupCache cache,
  String bookId,
  String key,
) {
  final ranges = [
    for (final row in cache.rows)
      if (row.bookId == bookId) ..._dpdRanges(row.tokens),
  ];
  // De-duplicated to keep the scan linear in distinct ranges.
  return _widestCovering(ranges.toSet(), key);
}

/// The row holding the widest DPD-range token covering [code], if any.
/// Sheet order lists outer ranges first, so the widest covering range is
/// the member's own row (`an4.274-783` beats `an4.277-303` for `an4.278`).
({SuttaLookupRow row, String range})? _coveringRow(
  SuttaLookupCache cache,
  String code,
) {
  SuttaLookupRow? bestRow;
  String? bestRange;
  var bestSpan = -1;
  for (final row in cache.rows) {
    final range = _coveringRangeInCell(row.tokens, code);
    if (range == null) continue;
    final parsed = _parseRange(range)!;
    final span = parsed.last - parsed.first;
    if (span > bestSpan) {
      bestRow = row;
      bestRange = range;
      bestSpan = span;
    }
  }
  if (bestRow == null || bestRange == null) return null;
  return (row: bestRow, range: bestRange);
}

/// The row's DPD display-bearer: first plain code (payload dashes count).
String? _displayBearer(List<SuttaToken> tokens) {
  for (final token in tokens) {
    if (token.marker.isEmpty && (!token.isDash || token.payload.isNotEmpty)) {
      return token.key;
    }
  }
  return null;
}

List<String> _aliasDashes(List<SuttaToken> tokens) => [
  for (final token in tokens)
    if (token.isRangeAlias && token.isDash) token.key,
];

List<String> _aliasPlains(List<SuttaToken> tokens) => [
  for (final token in tokens)
    if (token.isRangeAlias && !token.isDash) token.key,
];

/// The label a matched token shows. Verified against all 13,061 TSV keys
/// (scripts/import_sutta_codes.py parity check) to reproduce the old
/// asset's labels exactly from the token cells alone.
String _labelFor(SuttaLookupCache cache, SuttaLookupRow row, SuttaToken match) {
  if (match.payload.isNotEmpty) {
    return '${match.key.toUpperCase()} = ${match.payload.toUpperCase()}';
  }
  if (match.isMember) {
    // A range member opens its own paragraph but shows the range it sits
    // in: `AN1.5 (AN1.1-10)`. The range token usually lives in another
    // row of the same book.
    final range =
        _coveringRangeInCell(row.tokens, match.key) ??
        _coveringRangeInBook(cache, row.bookId, match.key);
    return range != null
        ? '${match.key.toUpperCase()} (${range.toUpperCase()})'
        : match.key.toUpperCase();
  }
  if (match.isKept) {
    // No row of its own: shows the covering range (`AN1.188-267`).
    final range =
        _coveringRangeInCell(row.tokens, match.key) ??
        _coveringRangeInBook(cache, row.bookId, match.key);
    return range?.toUpperCase() ?? match.key.toUpperCase();
  }
  final eqDashes = _aliasDashes(row.tokens);
  final eqPlains = _aliasPlains(row.tokens);
  if (match.isRangeAlias || eqDashes.isNotEmpty || eqPlains.isNotEmpty) {
    // `THI28 = THIG2.10`, `AN3.184 = AN3.183-352`. Only the row's
    // display-bearer and fellow aliases take this form — a samyutta code
    // sharing the paragraph (`sn39` next to `sn39.1`) keeps its own.
    final bearer = _displayBearer(row.tokens) ?? match.key;
    if (match.isRangeAlias || match.key == bearer) {
      final partner = (eqDashes + eqPlains).firstWhere(
        (_) => true,
        orElse: () => match.key,
      );
      return '${bearer.toUpperCase()} = ${partner.toUpperCase()}';
    }
  }
  return match.key.toUpperCase();
}

SuttaTarget _targetFor(
  SuttaLookupCache cache,
  SuttaLookupRow row,
  SuttaToken match,
) => SuttaTarget(
  bookId: row.bookId,
  paraId: row.paraId,
  displayCode: _labelFor(cache, row, match),
  title: row.title,
);

List<SuttaToken> _parseCell(String cell) => [
  for (final part in cell.split(RegExp(r'\s+')))
    if (part.isNotEmpty) parseToken(part),
];

List<SuttaLookupRow> _lookupRows(List<QueryRow> headingRows) => [
  for (final row in headingRows)
    SuttaLookupRow(
      bookId: row.read<String>('book_id'),
      paraId: row.read<int>('para_id'),
      title: row.read<String?>('title') ?? '',
      tokens: _parseCell(row.read<String?>('sc_id') ?? ''),
    ),
];

/// One heading's code cell from `assets/sutta_code_cells.tsv`.
class SuttaCodeCell {
  const SuttaCodeCell({required this.title, required this.cell});

  /// The heading title when the cell was built: a database whose heading at
  /// the same paragraph has another title is not the one the cell was built
  /// for.
  final String title;
  final String cell;
}

/// The code cells shipped with the app, one per heading of the books in the
/// DPD sutta sheet, keyed by book and paragraph. DPD's codes follow the CST
/// numbering. The codes inside an older `epitaka.db` can be one off from it
/// (its `sn45.172` is the Yogasutta, DPD's is the Oghasutta), and a new
/// database means a large download, so a fresh set ships with the app. A
/// cell fits only a database with the same paragraph numbers: see
/// [suttaCellsFit].
class SuttaCodeCells {
  SuttaCodeCells(this.rows);

  /// Reads the TSV: `book_id`, `para_id`, `title`, token cell. Lines that
  /// start with `#` are comments.
  factory SuttaCodeCells.parse(String tsv) {
    final rows = <(String, int), SuttaCodeCell>{};
    for (final line in tsv.split('\n')) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('\t');
      final paraId = parts.length >= 4 ? int.tryParse(parts[1]) : null;
      if (paraId == null) continue;
      rows[(parts[0], paraId)] = SuttaCodeCell(
        title: parts[2],
        cell: parts[3].trim(),
      );
    }
    return SuttaCodeCells(rows);
  }

  final Map<(String, int), SuttaCodeCell> rows;

  /// The books the cells cover. For these, the database's own codes are
  /// ignored, so an old stale code cannot sit beside a fresh one.
  late final Set<String> books = {for (final key in rows.keys) key.$1};
}

/// Whether [cells] were built for the paragraph numbers of [db]: about 40
/// spread-out cells must find a heading with the same title at the same
/// paragraph. A database release that renumbers paragraphs fails this, and
/// the database's own codes are used instead.
Future<bool> suttaCellsFit(EpitakaDatabase db, SuttaCodeCells cells) async {
  final keys = cells.rows.keys.toList();
  if (keys.isEmpty) return false;
  final step = (keys.length / 40).ceil();
  var probed = 0;
  var found = 0;
  for (var i = 0; i < keys.length; i += step) {
    final key = keys[i];
    probed++;
    final hit = await db
        .customSelect(
          'SELECT 1 FROM headings WHERE book_id = ? AND para_id = ? '
          "AND COALESCE(title, '') = ? LIMIT 1",
          variables: [
            Variable<String>(key.$1),
            Variable<int>(key.$2),
            Variable<String>(cells.rows[key]!.title),
          ],
        )
        .get();
    if (hit.isNotEmpty) found++;
  }
  return found * 10 >= probed * 9;
}

/// Load every heading up to level 10 plus the book names. Level-10 rows
/// are the individual suttas inside a vagga (`an1.1-10` members); without
/// them only the range row resolves. One round trip per dialog opening;
/// keystrokes then filter [SuttaLookupCache] in memory. With [cells] that fit
/// the database, the codes of the books they cover come from [cells].
Future<SuttaLookupCache> loadSuttaLookup(
  EpitakaDatabase db, {
  SuttaCodeCells? cells,
}) async {
  final headingRows = await db
      .customSelect(
        'SELECT book_id, para_id, title, sc_id FROM headings '
        'WHERE level <= 10 ORDER BY rowid',
      )
      .get();
  final bookRows = await db
      .customSelect('SELECT book_id, book_name FROM books')
      .get();
  var rows = _lookupRows(headingRows);
  if (cells != null && await suttaCellsFit(db, cells)) {
    final books = cells.books;
    rows = [
      for (final row in rows)
        if (!books.contains(row.bookId))
          row
        else
          SuttaLookupRow(
            bookId: row.bookId,
            paraId: row.paraId,
            title: row.title,
            tokens: _cellTokens(cells, row),
          ),
    ];
  }
  return SuttaLookupCache(
    rows: rows,
    bookNames: {
      for (final row in bookRows)
        row.read<String>('book_id'):
            row.read<String?>('book_name') ?? row.read<String>('book_id'),
    },
  );
}

/// The cell's tokens for [row], or none when the cell is for another heading.
List<SuttaToken> _cellTokens(SuttaCodeCells cells, SuttaLookupRow row) {
  final cell = cells.rows[(row.bookId, row.paraId)];
  if (cell == null || cell.title != row.title) return const [];
  return _parseCell(cell.cell);
}

/// Only the headings that carry a code, which is quick: about 30 ms instead
/// of 600 ms for [loadSuttaLookup]. [resolveSuttaCode] reads tokens only, so
/// it gives the same target as on [loadSuttaLookup]; titles and book names are
/// not searchable on this cache. With [cells] that fit the database, the books
/// they cover come from [cells] and need no database read.
Future<SuttaLookupCache> loadSuttaCodeLookup(
  EpitakaDatabase db, {
  SuttaCodeCells? cells,
}) async {
  if (cells != null && await suttaCellsFit(db, cells)) {
    final covered = cells.books.toList();
    final others = await db
        .customSelect(
          'SELECT book_id, para_id, title, sc_id FROM headings '
          'WHERE level <= 10 AND sc_id IS NOT NULL AND book_id NOT IN '
          '(${List.filled(covered.length, '?').join(',')}) ORDER BY rowid',
          variables: [for (final book in covered) Variable<String>(book)],
        )
        .get();
    return SuttaLookupCache(
      rows: [
        for (final entry in cells.rows.entries)
          SuttaLookupRow(
            bookId: entry.key.$1,
            paraId: entry.key.$2,
            title: entry.value.title,
            tokens: _parseCell(entry.value.cell),
          ),
        ..._lookupRows(others),
      ],
      bookNames: const {},
    );
  }
  final headingRows = await db
      .customSelect(
        'SELECT book_id, para_id, title, sc_id FROM headings '
        'WHERE level <= 10 AND sc_id IS NOT NULL ORDER BY rowid',
      )
      .get();
  return SuttaLookupCache(rows: _lookupRows(headingRows), bookNames: const {});
}

/// The one sutta a code opens: the first exact token match in canonical
/// (rowid) order, then the heading whose DPD range covers it. No prefix
/// list, so a link never opens a guess. Null when nothing matches.
SuttaTarget? resolveSuttaCode(SuttaLookupCache cache, String input) {
  final code = normaliseCode(input);
  if (code.isEmpty) return null;
  // Exact match (members included: `an1.5` opens its own paragraph).
  for (final row in cache.rows) {
    for (final token in row.tokens) {
      if (token.key == code) return _targetFor(cache, row, token);
    }
  }
  // Range synthesis: a member code with no stored token still opens the
  // heading whose range covers it, the way the old asset's expanded member
  // keys did. Stored tokens always win — this only runs on an exact miss.
  if (!code.contains('-')) {
    final covering = _coveringRow(cache, code);
    if (covering != null) {
      return SuttaTarget(
        bookId: covering.row.bookId,
        paraId: covering.row.paraId,
        displayCode: '${code.toUpperCase()} (${covering.range.toUpperCase()})',
        title: covering.row.title,
      );
    }
  }
  return null;
}

/// Code lookup over the `headings.sc_id` token cells: the exact match
/// first, then a range member with no token of its own (`an1.2` covered by
/// a bare `an1.1-10` row), then every non-member code starting with [input]
/// in canonical order — one entry per code per book, at most 20.
List<SuttaTarget> searchSuttaCodes(SuttaLookupCache cache, String input) {
  final code = normaliseCode(input);
  if (code.isEmpty) return const [];
  final seen = <String>{};
  final results = <SuttaTarget>[];
  void add(SuttaTarget target) {
    if (seen.add(target._identity)) results.add(target);
  }

  final resolved = resolveSuttaCode(cache, code);
  if (resolved != null) add(resolved);
  // Prefix matches, skipping range members: listing them all would push
  // the next ranges (`an10…` after `an1…`) out of the 20.
  for (final row in cache.rows) {
    if (results.length >= _maxResults) break;
    for (final token in row.tokens) {
      if (results.length >= _maxResults) break;
      if (token.isMember || token.key == code) continue;
      if (!token.key.startsWith(code)) continue;
      add(_targetFor(cache, row, token));
    }
  }
  return results;
}

String _primaryCode(SuttaLookupRow row) {
  for (final token in row.tokens) {
    if (token.marker.isEmpty && !token.isDash) {
      return token.key.toUpperCase();
    }
  }
  for (final token in row.tokens) {
    if (!token.isMember) return token.key.toUpperCase();
  }
  return row.bookId.toUpperCase();
}

/// Name lookup for when [searchSuttaCodes] finds nothing: matches
/// diacritic-insensitively against heading titles first, then book names,
/// so `satipatthana` finds MN10 and `vibhanga` the Vibhaṅga headings.
List<SuttaTarget> searchSuttaNames(SuttaLookupCache cache, String input) {
  final query = normalizeQuery(input).replaceAll(' ', '');
  if (query.length < 2) return const [];
  final seen = <String>{};
  final results = <SuttaTarget>[];
  void add(SuttaLookupRow row) {
    final target = SuttaTarget(
      bookId: row.bookId,
      paraId: row.paraId,
      displayCode: _primaryCode(row),
      title: row.title,
    );
    if (seen.add(target._identity)) results.add(target);
  }

  // Title hits outrank book-name hits.
  for (var pass = 0; pass < 2 && results.length < _maxResults; pass++) {
    for (final row in cache.rows) {
      if (results.length >= _maxResults) break;
      final titleHit = normalizeQuery(
        row.title,
      ).replaceAll(' ', '').contains(query);
      if (titleHit && pass == 0) {
        add(row);
        continue;
      }
      if (titleHit) continue;
      final bookName = cache.bookNames[row.bookId] ?? '';
      if (bookName.isEmpty || pass != 1) continue;
      if (normalizeQuery(bookName).replaceAll(' ', '').contains(query)) {
        add(row);
      }
    }
  }
  return results;
}

/// Regex name lookup for rx mode (spec G): [pattern] over the lower-cased
/// heading title, then the lower-cased book name — the same two-pass order
/// as [searchSuttaNames]. Diacritics are exact; `^` and `$` are the bounds
/// of the one title. Codes are not searched.
///
/// The match is a regex job (spec K): a runaway pattern throws
/// [RegexTooSlow], and [onJob] gets the job so the caller can cancel it.
Future<List<SuttaTarget>> searchSuttaNamesRegex(
  SuttaLookupCache cache,
  String pattern, {
  void Function(RegexJob<Object?> job)? onJob,
}) async {
  final rows = cache.rows;
  // Titles first, then each row's book name, in one job.
  final job = startRegexMatch(pattern, [
    for (final row in rows) [row.title.toLowerCase()],
    for (final row in rows)
      [(cache.bookNames[row.bookId] ?? '').toLowerCase()],
  ]);
  onJob?.call(job);
  final hits = (await job.result).hits.toSet();
  bool titleHit(int i) => hits.contains(i);
  bool bookHit(int i) => hits.contains(rows.length + i);

  final seen = <String>{};
  final results = <SuttaTarget>[];
  void add(SuttaLookupRow row) {
    final target = SuttaTarget(
      bookId: row.bookId,
      paraId: row.paraId,
      displayCode: _primaryCode(row),
      title: row.title,
    );
    if (seen.add(target._identity)) results.add(target);
  }

  // Title hits outrank book-name hits.
  for (var pass = 0; pass < 2 && results.length < _maxResults; pass++) {
    for (var i = 0; i < rows.length; i++) {
      if (results.length >= _maxResults) break;
      if (titleHit(i)) {
        if (pass == 0) add(rows[i]);
        continue;
      }
      if (pass == 1 && bookHit(i)) add(rows[i]);
    }
  }
  return results;
}

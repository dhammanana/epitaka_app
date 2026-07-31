/// A pure-Dart fuzzy string matching library inspired by fzf and
/// nucleo-matcher.  No native dependencies required.
///
/// The main entry point is [fuzzySearch] / [fuzzySearchWith].
///
/// ```dart
/// import 'package:epitaka/core/utils/fuzzy_matcher/fuzzy_matcher_library.dart';
///
/// final results = fuzzySearch(
///   query: 'miicuvanna',
///   candidates: myStrings,
///   limit: 10,
/// );
/// ```
library;

export 'fuzzy_matcher.dart' show fuzzySearch, fuzzySearchWith, normalizeQuery;
export 'result.dart' show ScoredMatch;

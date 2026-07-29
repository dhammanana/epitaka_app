import '../providers/reader_provider.dart';

/// Builds a citation string from the template by replacing placeholders.
///
/// The [template] can contain any of the following placeholders:
/// - `{book_id}` — the book's ID (e.g. "dn1")
/// - `{book_name}` — the full book name (e.g. "Brahmajāla Sutta")
/// - `{heading}` — the nearest section heading (e.g. "1. The Net of Views")
/// - `{para_id}` — the paragraph ID of the first selected paragraph
/// - `{vri_page}` — VRI edition page number
/// - `{pts_page}` — PTS edition page number
/// - `{thai_page}` — Thai edition page number
/// - `{myanmar_page}` — Myanmar edition page number
///
/// Both `{book_id}` and `{book_name}` are replaced regardless — the user
/// controls which one to use by typing the placeholder they want.
/// `{heading}` is replaced with the heading title if available, or removed.
/// `{para_id}` is replaced with the paraId string representation.
/// Each page placeholder is replaced with the correct value from
/// [pageNumbers] (keyed by system code: 'vri', 'pts', 'thai', 'my').
/// If a page number is missing for a system, the placeholder becomes empty.
String buildCitationFromTemplate(
  String template,
  String bookId,
  String? bookName,
  ParagraphHeading? heading,
  Map<String, String> pageNumbers, {
  int? paraId,
}) {
  String result = template;

  // Always replace both book_id and book_name — user picks which to use
  result = result.replaceAll('{book_id}', bookId);
  result = result.replaceAll('{book_name}', bookName ?? bookId);

  // Replace heading or remove the placeholder
  if (heading != null && heading.title.isNotEmpty) {
    result = result.replaceAll('{heading}', heading.title);
  } else {
    result = result.replaceAll('{heading}', '');
  }

  // Replace para_id placeholder with the paragraph ID
  if (paraId != null) {
    result = result.replaceAll('{para_id}', paraId.toString());
  } else {
    result = result.replaceAll('{para_id}', '');
  }

  // Replace each page placeholder with the correct value from the map
  result = result.replaceAll('{vri_page}', pageNumbers['vri'] ?? '');
  result = result.replaceAll('{pts_page}', pageNumbers['pts'] ?? '');
  result = result.replaceAll('{thai_page}', pageNumbers['thai'] ?? '');
  result = result.replaceAll('{myanmar_page}', pageNumbers['my'] ?? '');

  // Clean up: remove double spaces, leading/trailing punctuation when
  // a placeholder was empty, and trim.
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Remove dangling punctuation like "> " or "— " that was left when
  // {heading} was empty. Strips leading/trailing dashes, pipes, colons,
  // greater-than signs, and their surrounding whitespace.
  result = result.replaceAll(RegExp(r'^[\s>\-—:|,;.]+\s*'), '').trim();
  result = result.replaceAll(RegExp(r'\s*[\s>\-—:|,;.]+$'), '').trim();

  return result;
}

/// Returns a human-readable label for a page numbering system code.
String pageSystemLabel(String code) {
  switch (code) {
    case 'vri':
      return 'VRI';
    case 'pts':
      return 'PTS';
    case 'thai':
      return 'Thai';
    case 'my':
    case 'myanmar':
      return 'Myanmar';
    default:
      return 'VRI';
  }
}

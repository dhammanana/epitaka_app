import '../providers/reader_provider.dart';

/// Builds a citation string from the template by replacing placeholders.

/// Builds a citation string from the template by replacing placeholders.
/// Placeholders: {book_id}, {book_name}, {heading}, {vri_page}, {pts_page},
/// {thai_page}, {myanmar_page}
String buildCitationFromTemplate(
  String template,
  String bookId,
  String? bookName,
  ParagraphHeading? heading,
  String? pageNumber,
  String quotePageSystem,
  bool useBookName,
  bool includeHeading,
) {
  String result = template;

  // Replace {book_id} or {book_name}
  if (useBookName) {
    result = result.replaceAll('{book_name}', bookName ?? bookId);
  } else {
    result = result.replaceAll('{book_id}', bookId);
  }

  // Replace {heading}
  if (includeHeading && heading != null && heading.title.isNotEmpty) {
    result = result.replaceAll('{heading}', heading.title);
  } else {
    result = result.replaceAll('{heading}', '');
  }

  // Replace page placeholders - use the current page numbering system
  result = result.replaceAll('{vri_page}', pageNumber ?? '');
  result = result.replaceAll('{pts_page}', pageNumber ?? '');
  result = result.replaceAll('{thai_page}', pageNumber ?? '');
  result = result.replaceAll('{myanmar_page}', pageNumber ?? '');

  // Clean up double spaces and trim
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

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

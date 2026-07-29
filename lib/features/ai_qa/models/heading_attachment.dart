/// Data model for a Tipitaka heading/sutta attached to a chat message via
/// the @ mention system.
///
/// Supports two entry types:
///   - **book**: A complete sutta/book (paraId=0), with full Pāli text and
///     commentary references (mulaRef, atthaRef, tikaRef).
///   - **heading**: A specific section within a book, with hierarchy path.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Whether the attached entry is a full book or a heading within a book.
enum AttachmentEntryType { book, heading }

/// A heading or book attached to a chat message via the @ mention system.
class HeadingAttachment {
  final String id;
  final String bookId;
  final int paraId;
  final String title;
  final String bookName;
  final AttachmentEntryType entryType;

  /// Ordered list of ancestor titles from root to this heading.
  /// For books, this is usually [bookName].
  final List<String> hierarchy;

  /// Total paragraph count for the book (from books.chapter_len).
  final int chapterLen;

  /// Reference to the mūla (root) text for finding commentaries.
  final String? mulaRef;

  /// Reference to the aṭṭhakathā (commentary).
  final String? atthaRef;

  /// Reference to the ṭīkā (sub-commentary).
  final String? tikaRef;

  /// Full Pāli text of the attached section (trimmed to ~200k chars).
  /// Populated asynchronously before the message is sent.
  final String? fullText;

  const HeadingAttachment({
    required this.id,
    required this.bookId,
    required this.paraId,
    required this.title,
    required this.bookName,
    this.entryType = AttachmentEntryType.heading,
    this.hierarchy = const [],
    this.chapterLen = 0,
    this.mulaRef,
    this.atthaRef,
    this.tikaRef,
    this.fullText,
  });

  factory HeadingAttachment.create({
    required String bookId,
    required int paraId,
    required String title,
    required String bookName,
    AttachmentEntryType entryType = AttachmentEntryType.heading,
    List<String> hierarchy = const [],
    int chapterLen = 0,
    String? mulaRef,
    String? atthaRef,
    String? tikaRef,
    String? fullText,
  }) {
    return HeadingAttachment(
      id: _uuid.v4(),
      bookId: bookId,
      paraId: paraId,
      title: title,
      bookName: bookName,
      entryType: entryType,
      hierarchy: hierarchy,
      chapterLen: chapterLen,
      mulaRef: mulaRef,
      atthaRef: atthaRef,
      tikaRef: tikaRef,
      fullText: fullText,
    );
  }

  /// Short label shown in the attachment chip.
  /// e.g. "DN1 › Brahmajālasuttaṃ"  or  "MN 95 › Cūḷakammavibhaṅgasuttaṃ"
  String get chipLabel {
    final book = bookName.isNotEmpty ? bookName : bookId;
    if (entryType == AttachmentEntryType.book) {
      return '$book ($bookId)';
    }
    return '$book › $title';
  }

  /// Full context block injected into the AI prompt when this attachment is sent.
  /// For book entries, includes full Pāli text + commentary references.
  String get contextBlock {
    final buffer = StringBuffer();

    if (entryType == AttachmentEntryType.book) {
      buffer.writeln('═══════════════════════════════════════════');
      buffer.writeln('ATTACHED BOOK: $bookName ($bookId)');
      if (chapterLen > 0) buffer.writeln('Length: $chapterLen paragraphs');
      buffer.writeln('═══════════════════════════════════════════');

      // Commentary references
      final refs = <String>[];
      if (mulaRef != null && mulaRef!.isNotEmpty) refs.add('Mūla: $mulaRef');
      if (atthaRef != null && atthaRef!.isNotEmpty) refs.add('Aṭṭhakathā: $atthaRef');
      if (tikaRef != null && tikaRef!.isNotEmpty) refs.add('Ṭīkā: $tikaRef');
      if (refs.isNotEmpty) {
        buffer.writeln('Related texts: ${refs.join(' | ')}');
        buffer.writeln();
      }

      // Full Pāli text
      if (fullText != null && fullText!.isNotEmpty) {
        buffer.writeln('Pāli text:');
        buffer.writeln(fullText);
        buffer.writeln();
      }
    } else {
      // Heading entry
      final book = bookName.isNotEmpty ? '$bookName ($bookId)' : bookId;
      final path = hierarchy.isNotEmpty ? ' › ${hierarchy.join(' › ')}' : '';
      buffer.writeln('📖 Attached heading: $book$path — $title [@$bookId §$paraId]');
    }

    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'book_id': bookId,
        'para_id': paraId,
        'title': title,
        'book_name': bookName,
        'entry_type': entryType.name,
        'hierarchy': hierarchy,
        'chapter_len': chapterLen,
        'mula_ref': mulaRef,
        'attha_ref': atthaRef,
        'tika_ref': tikaRef,
        'full_text': fullText,
      };

  factory HeadingAttachment.fromJson(Map<String, dynamic> json) {
    return HeadingAttachment(
      id: json['id'] as String? ?? _uuid.v4(),
      bookId: json['book_id'] as String,
      paraId: (json['para_id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      bookName: json['book_name'] as String? ?? '',
      entryType: json['entry_type'] == 'book'
          ? AttachmentEntryType.book
          : AttachmentEntryType.heading,
      hierarchy: (json['hierarchy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      chapterLen: (json['chapter_len'] as num?)?.toInt() ?? 0,
      mulaRef: json['mula_ref'] as String?,
      atthaRef: json['attha_ref'] as String?,
      tikaRef: json['tika_ref'] as String?,
      fullText: json['full_text'] as String?,
    );
  }
}

/// Search result from the mention index, used in the dropdown.
class MentionSearchResult {
  final String bookId;
  final int paraId;
  final String title;
  final String bookName;
  final AttachmentEntryType entryType;

  /// The full @-path for display.
  /// e.g. "@dn1/brahmajālasuttaṃ/1. Sīla" or "@mn95/cūḷakammavibhaṅgasuttaṃ"
  final String path;

  /// Hierarchy breadcrumb for the result display.
  final List<String> hierarchy;

  /// Whether this book is a mūla (root) text.
  final bool isMula;

  /// Total paragraph count (from books.chapter_len), shown for book entries.
  final int chapterLen;

  /// Reference to the mūla (root) text.
  final String? mulaRef;

  /// Reference to the aṭṭhakathā (commentary).
  final String? atthaRef;

  /// Reference to the ṭīkā (sub-commentary).
  final String? tikaRef;

  /// Normalized search text used for FZF-style fuzzy matching.
  /// Populated from the `search_text` column in the mention_index.
  final String searchText;

  const MentionSearchResult({
    required this.bookId,
    required this.paraId,
    required this.title,
    required this.bookName,
    this.entryType = AttachmentEntryType.heading,
    required this.path,
    this.hierarchy = const [],
    this.isMula = true,
    this.chapterLen = 0,
    this.mulaRef,
    this.atthaRef,
    this.tikaRef,
    this.searchText = '',
  });

  /// Convert to a [HeadingAttachment] when the user selects this result.
  HeadingAttachment toAttachment() {
    return HeadingAttachment.create(
      bookId: bookId,
      paraId: paraId,
      title: title,
      bookName: bookName,
      entryType: entryType,
      hierarchy: hierarchy,
      chapterLen: chapterLen,
      mulaRef: mulaRef,
      atthaRef: atthaRef,
      tikaRef: tikaRef,
    );
  }

  /// Short hierarchy preview for the dropdown item subtitle.
  /// For book entries, shows the book name.
  /// For heading entries, shows the hierarchy path.
  String get subtitle {
    if (entryType == AttachmentEntryType.book) {
      return bookName.isNotEmpty ? bookName : bookId;
    }
    final book = bookName.isNotEmpty ? bookName : bookId;
    if (hierarchy.length > 1) {
      return '$book › ${hierarchy.sublist(0, hierarchy.length - 1).join(' › ')}';
    }
    return book;
  }

  /// Formatted chapter length for display, e.g. "142 paragraphs".
  String get chapterLenLabel {
    if (chapterLen <= 0) return '';
    if (chapterLen >= 1000) {
      return '${(chapterLen / 1000).toStringAsFixed(1)}k paragraphs';
    }
    return '$chapterLen paragraphs';
  }
}

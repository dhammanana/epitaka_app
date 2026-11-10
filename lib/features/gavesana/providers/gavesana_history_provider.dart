import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/history_store.dart';
import '../../search/providers/search_provider.dart' show AiPassageRef;

final gavesanaHistoryProvider =
    StateNotifierProvider<GavesanaHistoryNotifier, List<String>>(
      (ref) => GavesanaHistoryNotifier(),
    );

/// A finished Gavesana run: the question, the terms the AI used and the
/// passages it found (book id and paragraph id only).
class GavesanaEntry {
  final String question;
  final List<String> terms;
  final List<AiPassageRef> passages;
  const GavesanaEntry({
    required this.question,
    required this.terms,
    required this.passages,
  });
}

class GavesanaHistoryNotifier extends HistoryStore {
  GavesanaHistoryNotifier()
    : super(storageKey: 'gavesana_search_history', capacity: 15);

  @override
  String identity(String entry) {
    final e = decodeGavesana(entry);
    return e == null ? entry : e.question.trim().toLowerCase();
  }

  @override
  bool accepts(String entry) => decodeGavesana(entry) != null;
}

String encodeGavesana({
  required String question,
  required List<String> terms,
  required List<AiPassageRef> passages,
}) => jsonEncode({
  'q': question.trim(),
  't': terms,
  'p': [
    for (final p in passages) [p.bookId, p.paraId],
  ],
});

GavesanaEntry? decodeGavesana(String s) {
  try {
    final m = jsonDecode(s);
    if (m is! Map) return null;
    final q = m['q'], t = m['t'], p = m['p'];
    if (q is! String || t is! List || p is! List || p.isEmpty) return null;
    if (t.any((x) => x is! String)) return null;
    final passages = <AiPassageRef>[];
    for (final x in p) {
      if (x is! List || x.length != 2 || x[0] is! String || x[1] is! int) {
        return null;
      }
      passages.add(AiPassageRef(bookId: x[0] as String, paraId: x[1] as int));
    }
    return GavesanaEntry(
      question: q,
      terms: List<String>.from(t),
      passages: passages,
    );
  } on FormatException {
    return null;
  }
}

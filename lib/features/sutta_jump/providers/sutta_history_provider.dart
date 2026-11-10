import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/history_store.dart';
import '../services/sutta_code_service.dart';

final suttaHistoryProvider =
    StateNotifierProvider<SuttaHistoryNotifier, List<String>>(
      (ref) => SuttaHistoryNotifier(),
    );

/// Suttas opened from the "Go to sutta" box. Each entry is one JSON string
/// with `b` (book id), `p` (paragraph id), `c` (display code), `t` (title).
class SuttaHistoryNotifier extends HistoryStore {
  SuttaHistoryNotifier() : super(storageKey: 'goto_sutta_history', capacity: 30);

  @override
  String identity(String entry) {
    final t = decodeSutta(entry);
    return t == null ? entry : '${t.bookId}|${t.paraId}';
  }

  @override
  bool accepts(String entry) => decodeSutta(entry) != null;
}

String encodeSutta(SuttaTarget t) => jsonEncode({
  'b': t.bookId,
  'p': t.paraId,
  'c': t.displayCode,
  't': t.title,
});

SuttaTarget? decodeSutta(String s) {
  try {
    final m = jsonDecode(s);
    if (m is! Map) return null;
    final b = m['b'], p = m['p'], c = m['c'], t = m['t'];
    if (b is! String || p is! int || c is! String || t is! String) return null;
    return SuttaTarget(bookId: b, paraId: p, displayCode: c, title: t);
  } on FormatException {
    return null;
  }
}

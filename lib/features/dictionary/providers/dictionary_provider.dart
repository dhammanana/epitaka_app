import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the dictionary panel.
class DictionaryState {
  final bool isOpen;
  final String word;

  const DictionaryState({
    this.isOpen = false,
    this.word = '',
  });

  DictionaryState copyWith({bool? isOpen, String? word}) {
    return DictionaryState(
      isOpen: isOpen ?? this.isOpen,
      word: word ?? this.word,
    );
  }
}

/// Notifier for the dictionary panel state.
class DictionaryNotifier extends StateNotifier<DictionaryState> {
  DictionaryNotifier() : super(const DictionaryState());

  void open(String word) {
    debugPrint('[DICT] Opening dictionary for: $word');
    state = DictionaryState(isOpen: true, word: word);
  }

  void close() {
    state = const DictionaryState();
  }

  void setWord(String word) {
    state = state.copyWith(word: word);
  }
}

/// Provider for the dictionary panel state.
final dictionaryProvider =
    StateNotifierProvider<DictionaryNotifier, DictionaryState>((ref) {
  return DictionaryNotifier();
});

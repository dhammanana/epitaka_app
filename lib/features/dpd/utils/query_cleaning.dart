import '../../../core/utils/pali_script_converter.dart';

/// Folds niggahīta (`ṁ`, `ŋ` → `ṃ`) and drops `?` and `!`, so one word has
/// one spelling in the history, the suggestion keys and the lookup.
String foldDpdQuery(String text) => text
    .replaceAll('ṁ', 'ṃ')
    .replaceAll('ŋ', 'ṃ')
    .replaceAll('?', '')
    .replaceAll('!', '');

/// What the sheet and the panel look up, whether the word was typed, tapped,
/// chosen from the suggestions or handed in by the reader. Any script becomes
/// Roman and niggahīta is folded. Velthuis is not applied here: the field
/// converts typing as it happens, and any other word keeps its own spelling
/// (a real `aa`, or English such as `vacuum`).
String cleanDpdQuery(String raw) =>
    foldDpdQuery(convertToRomanPali(raw)).trim();

/// The word under a tap inside an entry, ready to look up: any script turned
/// into Roman, punctuation dropped, niggahīta folded. A dot between two digits
/// stays, because it is part of a sutta number (`SN1.16`); any other dot goes.
String cleanTappedWord(String raw) {
  final stripped = convertToRomanPali(raw).replaceAll(
    RegExp(r'[^\p{L}\p{M}\p{Nd}_\s.]', unicode: true),
    '',
  );
  final dots = stripped.replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)'), '');
  return foldDpdQuery(dots).trim();
}

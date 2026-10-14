import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/velthuis.dart';

/// Folds niggahīta (`ṁ`, `ŋ` → `ṃ`) and drops `?` and `!`, so one word has
/// one spelling in the history, the suggestion keys and the lookup.
String foldDpdQuery(String text) => text
    .replaceAll('ṁ', 'ṃ')
    .replaceAll('ŋ', 'ṃ')
    .replaceAll('?', '')
    .replaceAll('!', '');

/// What the sheet and the panel search with. [velthuis] turns any script into
/// Roman first, so the field itself can keep what the user typed.
String cleanDpdQuery(String raw) => foldDpdQuery(velthuis(raw)).trim();

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

/// A word that was not typed here: one tapped inside an entry, chosen from the
/// suggestions, or handed in by the reader. Any script becomes Roman and
/// niggahīta is folded, but [velthuis] is NOT applied: it would turn the English
/// `vacuum` into `vacūm` and `aardvark` into `ārdvark`.
String cleanShownWord(String raw) =>
    foldDpdQuery(convertToRomanPali(raw)).trim();

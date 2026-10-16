import 'package:flutter/services.dart';

/// The Pāli Velthuis rules, as typed → as shown. The help icon in the search
/// boxes lists the lowercase ones straight from here, so the card and the
/// converter agree.
const velthuisRules = [
  // Long vowels (lowercase)
  ('aa', 'ā'),
  ('ii', 'ī'),
  ('uu', 'ū'),
  // Velar nasal
  ('"n', 'ṅ'),
  // Palatal nasal
  ('~n', 'ñ'),
  // Retroflex / dental specials (dot notation)
  ('.t', 'ṭ'),
  ('.d', 'ḍ'),
  ('.n', 'ṇ'),
  ('.m', 'ṃ'),
  ('.l', 'ḷ'),
  // Uppercase long vowels
  ('AA', 'Ā'),
  ('II', 'Ī'),
  ('UU', 'Ū'),
  // Uppercase consonants
  ('"N', 'Ṅ'),
  ('~N', 'Ñ'),
  ('.T', 'Ṭ'),
  ('.D', 'Ḍ'),
  ('.N', 'Ṇ'),
  ('.M', 'Ṃ'),
  ('.L', 'Ḷ'),
];

/// The Sanskrit letters Pāli lacks, in standard Velthuis. The help card lists
/// them under the Pāli rows.
const velthuisSanskritRules = [
  ('"s', 'ś'),
  ('.s', 'ṣ'),
  ('.r', 'ṛ'),
  ('.rr', 'ṝ'),
  ('.ll', 'ḹ'),
  ('.h', 'ḥ'),
  ('"S', 'Ś'),
  ('.S', 'Ṣ'),
  ('.R', 'Ṛ'),
  ('.RR', 'Ṝ'),
  ('.LL', 'Ḹ'),
];

/// Typing a vowel three times gives the plain double vowel, for words the
/// canon spells that way (`Dutiyaanuruddha`, `theraapadāna`). The card lists
/// these under the Pāli rows.
const velthuisDoubleVowels = [('aaa', 'aa'), ('iii', 'ii'), ('uuu', 'uu')];

/// The rules as they meet the cursor. Typing goes one key at a time, so by
/// the last key part of the rule is already converted: `.rr` is `ṛ` when the
/// second `r` comes, and `aaa` is `ā` when the third `a` comes.
const _paliFixups = [
  ('āa', 'aa'),
  ('īi', 'ii'),
  ('ūu', 'uu'),
  ('ĀA', 'AA'),
  ('ĪI', 'II'),
  ('ŪU', 'UU'),
];
const _sanskritFixups = [
  ('ṛr', 'ṝ'),
  ('ḷl', 'ḹ'),
  ('ṚR', 'Ṝ'),
  ('ḶL', 'Ḹ'),
];
const _paliTyping = [..._paliFixups, ...velthuisRules];
const _allTyping = [
  ..._paliFixups,
  ..._sanskritFixups,
  ...velthuisRules,
  ...velthuisSanskritRules,
];

/// The one way a box where Pāli is typed turns Velthuis into diacritics:
/// `inputFormatters: const [VelthuisInputFormatter()]`.
///
/// Only typing converts: an edit that adds one character at the cursor, and
/// only the rule whose key that character completes. A paste stays exactly
/// as pasted, so the canon's own spellings (`theraapadāna`) survive. It runs
/// before `onChanged`, so the box's own code already sees the result.
/// Every key is plain Latin, so Myanmar, Thai, … typing completes no rule and
/// stays as typed; the search turns it into Roman with `convertToRomanPali`.
class VelthuisInputFormatter extends TextInputFormatter {
  /// Off for boxes where English is typed: there `"sati"` must stay a quoted
  /// word, not become `śati"`.
  final bool sanskrit;

  const VelthuisInputFormatter({this.sanskrit = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final cursor = newValue.selection.baseOffset;
    if (!newValue.selection.isCollapsed || cursor < 1) return newValue;

    // One key typed where the old cursor was, or over the old selection. The
    // text must match exactly: a backspace after a paste can leave the same
    // letters at the cursor, and must not convert them.
    final old = oldValue.text;
    final selStart = oldValue.selection.start;
    final selEnd = oldValue.selection.end;
    if (selStart != cursor - 1 ||
        selEnd < selStart ||
        selEnd > old.length ||
        old.replaceRange(selStart, selEnd, text[cursor - 1]) != text) {
      return newValue;
    }

    final before = text.substring(0, cursor);
    for (final (from, to) in sanskrit ? _allTyping : _paliTyping) {
      if (!before.endsWith(from)) continue;
      final start = cursor - from.length;
      return TextEditingValue(
        text: text.substring(0, start) + to + text.substring(cursor),
        selection: TextSelection.collapsed(offset: start + to.length),
      );
    }
    return newValue;
  }
}

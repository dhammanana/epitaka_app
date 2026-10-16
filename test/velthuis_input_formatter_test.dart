import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/utils/velthuis.dart';

/// Runs [keys] through the formatter one key at a time, each typed at the
/// cursor, starting from [start] with the cursor at [at] (default: the end).
TextEditingValue _type(
  String keys, {
  String start = '',
  int? at,
  bool sanskrit = true,
}) {
  final formatter = VelthuisInputFormatter(sanskrit: sanskrit);
  var value = TextEditingValue(
    text: start,
    selection: TextSelection.collapsed(offset: at ?? start.length),
  );
  for (final key in keys.split('')) {
    final cursor = value.selection.baseOffset;
    final typed = TextEditingValue(
      text: value.text.replaceRange(cursor, cursor, key),
      selection: TextSelection.collapsed(offset: cursor + 1),
    );
    value = formatter.formatEditUpdate(value, typed);
  }
  return value;
}

void main() {
  test('typing converts and the caret stays after the new letter', () {
    final out = _type('dhamma.m');
    expect(out.text, 'dhammaṃ');
    expect(out.selection.baseOffset, 7);
  });

  test('typing in the middle converts there and keeps the caret', () {
    final out = _type('a', start: 'pa zz', at: 2);
    expect(out.text, 'pā zz');
    expect(out.selection.baseOffset, 2);
  });

  test('every rule converts when typed, Sanskrit and capitals included', () {
    for (final (from, to) in [...velthuisRules, ...velthuisSanskritRules]) {
      expect(_type(from).text, to, reason: 'rule $from');
    }
  });

  test('the long Sanskrit letters can be typed key by key', () {
    expect(_type('k.rr.s.na').text, 'kṝṣṇa');
    expect(_type('.ll').text, 'ḹ');
    expect(_type('.RR').text, 'Ṝ');
    expect(_type('k.r.s.na').text, 'kṛṣṇa');
  });

  test('a vowel typed three times gives the plain double vowel', () {
    for (final (from, to) in velthuisDoubleVowels) {
      expect(_type(from).text, to, reason: 'escape $from');
      expect(_type(from, sanskrit: false).text, to, reason: 'escape $from');
    }
    expect(_type('dutiyaaanu').text, 'dutiyaanu');
    expect(_type('AAA').text, 'AA');
  });

  test('a paste stays exactly as pasted', () {
    const pasted = TextEditingValue(
      text: 'theraapadaana dhamma.m',
      selection: TextSelection.collapsed(offset: 22),
    );
    final out = const VelthuisInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      pasted,
    );
    expect(identical(out, pasted), isTrue);
  });

  test('a key typed after pasted text converts only its own pair', () {
    // "aa" from the paste stays; the new ".m" converts.
    expect(_type('.m', start: 'theraa').text, 'theraaṃ');
  });

  test('without Sanskrit, a quoted s-word stays as typed', () {
    expect(_type('"sati"', sanskrit: false).text, '"sati"');
    expect(_type('"sati"').text, 'śati"');
    expect(_type('paali', sanskrit: false).text, 'pāli');
  });

  test('Myanmar typing is left as typed', () {
    expect(_type('ဓမ္မ').text, 'ဓမ္မ');
    // Roman typed next to it still converts: the check is per key, not per box.
    expect(_type('aa', start: 'ဓမ္မ ').text, 'ဓမ္မ ā');
  });

  test('a newline, curly quote or dash earlier on does not stop it', () {
    expect(_type('paali', start: 'dhamma\n').text, 'dhamma\npāli');
    expect(_type('paali', start: 'what’s ').text, 'what’s pāli');
    expect(_type('paali', start: 'evaṃ me sutaṃ — ').text,
        'evaṃ me sutaṃ — pāli');
  });

  test('typing over a selection converts like typing', () {
    const old = TextEditingValue(
      text: 'pali',
      selection: TextSelection(baseOffset: 2, extentOffset: 4),
    );
    const typed = TextEditingValue(
      text: 'paa',
      selection: TextSelection.collapsed(offset: 3),
    );
    final out = const VelthuisInputFormatter().formatEditUpdate(old, typed);
    expect(out.text, 'pā');
  });

  test('a backspace after a paste leaves the pasted letters alone', () {
    const old = TextEditingValue(
      text: 'theraax',
      selection: TextSelection.collapsed(offset: 7),
    );
    const typed = TextEditingValue(
      text: 'theraa',
      selection: TextSelection.collapsed(offset: 6),
    );
    final out = const VelthuisInputFormatter().formatEditUpdate(old, typed);
    expect(identical(out, typed), isTrue);
  });

  test('a key that completes nothing comes back untouched', () {
    const old = TextEditingValue(
      text: 'dhamm',
      selection: TextSelection.collapsed(offset: 5),
    );
    const typed = TextEditingValue(
      text: 'dhamma',
      selection: TextSelection.collapsed(offset: 6),
      composing: TextRange(start: 0, end: 6),
    );
    final out = const VelthuisInputFormatter().formatEditUpdate(old, typed);
    expect(identical(out, typed), isTrue,
        reason: 'the keyboard keeps its composing word');
  });
}

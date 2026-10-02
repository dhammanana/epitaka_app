import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/models/shortcut_override.dart';

void main() {
  bool sameCombo(SingleActivator? a, SingleActivator b) =>
      a != null &&
      a.trigger == b.trigger &&
      a.control == b.control &&
      a.shift == b.shift &&
      a.alt == b.alt &&
      a.meta == b.meta;

  test('Ctrl+Shift+K survives a save and load', () {
    const combo = SingleActivator(
      LogicalKeyboardKey.keyK,
      control: true,
      shift: true,
    );
    final loaded = decodeOverrides(encodeOverrides({'dictionary': combo}));
    expect(loaded.keys, ['dictionary']);
    expect(sameCombo(loaded['dictionary'], combo), isTrue);
  });

  test('a bare letter survives a save and load', () {
    const combo = SingleActivator(LogicalKeyboardKey.keyJ);
    final loaded = decodeOverrides(encodeOverrides({'search-next': combo}));
    expect(sameCombo(loaded['search-next'], combo), isTrue);
  });

  test('a character key outside Flutter\'s table survives a reload', () {
    // ā (U+0101) on a Pāḷi keyboard layout.
    const combo = SingleActivator(LogicalKeyboardKey(0x101), control: true);
    final loaded = decodeOverrides(encodeOverrides({'dictionary': combo}));
    expect(sameCombo(loaded['dictionary'], combo), isTrue);
  });

  test('a shortcut with no keys survives a save and load', () {
    final loaded = decodeOverrides(encodeOverrides({'find-in-book': null}));
    expect(loaded.containsKey('find-in-book'), isTrue);
    expect(loaded['find-in-book'], isNull);
  });

  test('bad data gives an empty map instead of throwing', () {
    expect(decodeOverrides(null), isEmpty);
    expect(decodeOverrides(''), isEmpty);
    expect(decodeOverrides('not json'), isEmpty);
    expect(decodeOverrides('[]'), isEmpty);
    expect(decodeOverrides('{"x": {"key": 999999999999}}'), isEmpty);
    expect(decodeOverrides('{"x": {"key": "k"}}'), isEmpty);
    expect(decodeOverrides('{"x": 3}'), isEmpty);
  });

  test('one bad entry is dropped and the good one kept', () {
    final raw =
        '{"bad": {"key": 999999999999}, '
        '"good": {"key": ${LogicalKeyboardKey.keyN.keyId}, "control": true}}';
    final loaded = decodeOverrides(raw);
    expect(loaded.keys, ['good']);
    expect(
      sameCombo(
        loaded['good'],
        const SingleActivator(LogicalKeyboardKey.keyN, control: true),
      ),
      isTrue,
    );
  });
}

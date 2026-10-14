import 'dart:io';

import 'package:epitaka/features/dpd/database/dpd_quick_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';

void main() {
  late Directory dir;
  late DpdQuickLookup quick;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_quick_lookup_test');
    quick = DpdQuickLookup.open(buildDpdFixture(dir).path);
  });

  tearDownAll(() async {
    quick.dispose();
    await dir.delete(recursive: true);
  });

  test('a word with headwords has content', () {
    expect(quick.hasContent('dhamma'), isTrue);
  });

  test('a row with only one content column still counts', () {
    expect(quick.hasContent('abba'), isTrue, reason: 'deconstructor only');
    expect(quick.hasContent('rokho'), isTrue, reason: 'spelling only');
    expect(quick.hasContent('anugā'), isTrue, reason: 'roots');
  });

  test('a row whose content columns are all empty is a miss', () {
    // `neut` is an abbreviation: it has a row, but none of the eight columns.
    expect(quick.hasContent('neut'), isFalse);
  });

  test('no row is a miss', () {
    expect(quick.hasContent('zzzqx'), isFalse);
    expect(quick.hasContent(''), isFalse);
  });

  test('the key is lower-cased and the circle niggahīta is folded', () {
    expect(quick.hasContent('Dhamma'), isTrue);
    expect(quick.hasContent('taṁ'), isTrue);
  });

  // SQLite makes `-wal` and `-shm` files even for a read-only open of a
  // WAL-mode file (checked), so this holds only for the plain-journal files
  // the installer produces; `dpd_install_test` checks that conversion.
  test('opening a plain-journal file leaves no side files', () {
    final names = dir.listSync().map((e) => e.uri.pathSegments.last).toList();
    expect(names, ['dpd-mobile.db']);
  });
}

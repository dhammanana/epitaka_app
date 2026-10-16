/// A typed sutta number keeps its dot, so `SN1.16` is a direct hit, not a
/// "Did you mean" (Q13; the typed path had no test, 5.6a).
library;

import 'dart:io';

import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/dpd/utils/query_cleaning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('typed_sutta_code_test');
    dbFile = buildDpdFixture(dir);
    final db = sqlite3.open(dbFile.path);
    try {
      db.execute(File('test/fixtures/dpd_sn116.sql').readAsStringSync());
    } finally {
      db.dispose();
    }
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  testWidgets('typed SN1.16 finds its two headwords', (tester) async {
    final c = await makeShellContainer(tester, dbFile);
    final query = cleanDpdQuery('SN1.16');
    expect(query, 'SN1.16');
    final lookup = await tester.runAsync(
      () => c.read(dpdLookupProvider(query).future),
    );
    expect(lookup!.headwords.map((h) => h.headword.id), [35620, 37223]);
  });
}

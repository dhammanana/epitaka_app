import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/app_database.dart';

void main() {
  group('default TTS replacements', () {
    test('fresh database seeds the enabled bracket-removal regex', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final rules = await db.getAllTtsReplacements();
      final seeded =
          rules.where((r) => r.pattern == r'\[.*?\]').toList(growable: false);
      expect(seeded, hasLength(1));
      expect(seeded.single.isRegex, isTrue);
      expect(seeded.single.enabled, isTrue);
      expect(seeded.single.replacement, '');
    });

    test('seeding again does not duplicate the rule', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.ensureDefaultTtsReplacements();
      await db.ensureDefaultTtsReplacements();

      final rules = await db.getAllTtsReplacements();
      expect(rules.where((r) => r.pattern == r'\[.*?\]'), hasLength(1));
    });

    test('seeded rule strips bracketed alternative readings', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await db.applyTtsReplacements('dhammo [dhamma] hoti'),
        isNot(contains('[')),
      );
    });
  });
}

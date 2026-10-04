/// Tests for the variant-annotation search contract:
///
/// `cleanPaliForIndexing` keeps the *content* of bracketed variant spans
/// (`[variant reading]`) by default, so variant-only words are searchable
/// in the global FTS index and via `normalizePaliFuzzy`. The whole-span
/// removal survives as the opt-in `stripVariantContent` mode, used by
/// in-book search when the user hides variant readings.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/pali_search_utils.dart';
import 'package:epitaka/features/reader/providers/reader_search_notifier.dart';

void main() {
  group('cleanPaliForIndexing variant content (default keeps content)', () {
    test('keeps bracket content and drops only the bracket characters', () {
      final out = cleanPaliForIndexing('dhammo ca [dhammo] ca');
      expect(out, contains('dhammo ca dhammo ca'));
      expect(out.contains('['), isFalse);
      expect(out.contains(']'), isFalse);
    });

    test('bracket-adjacent variants delimit instead of merging', () {
      // A bracket glued to a word must not fuse into a single token.
      expect(cleanPaliForIndexing('buddh[o]'), contains('buddh o'));
    });

    test('reference-style brackets with digits are dropped', () {
      // Manuscript/page citations are not variant readings.
      final out = cleanPaliForIndexing(
        'vuttam [ka.517; rū.488] hoti [udā.27] [abhidhāna 392 gāthā]',
      );
      expect(out, isNot(contains('517')));
      expect(out, isNot(contains('udā27')));
      expect(out, isNot(contains('392')));
      expect(out, contains('vuttam'));
      expect(out, contains('hoti'));
    });

    test('a variant-only word survives the default pipeline', () {
      final out = cleanPaliForIndexing('bhikkhave [apāṇakoṭikaṃ]');
      expect(out, contains('apāṇakoṭikaṃ'));
    });

    test('stripVariantContent removes the whole span (legacy behavior)', () {
      final out = cleanPaliForIndexing(
        'dhammo ca [dhammo] ca',
        stripVariantContent: true,
      );
      expect(out, isNot(contains('dhammo dhammo')));
      expect(out, 'dhammo ca ca');
    });
  });

  group('normalizePaliFuzzy matches variant-only terms', () {
    test('term occurring only inside brackets is found (default)', () {
      final line = normalizePaliFuzzy(
        cleanPaliForIndexing('sabbe [apāṇakoṭikaṃ]'),
      );
      final term = normalizePaliFuzzy(cleanPaliForIndexing('apāṇakoṭikaṃ'));
      expect(line.contains(term), isTrue);
    });
  });

  group('in-book search normalization follows the toggle', () {
    test(
      'strip=true (variants hidden): variant-only word is not searchable',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(settingsProvider.notifier).state = AppSettings(
          stripVariantAnnotations: true,
        );
        final notifier = container.read(inBookSearchProvider.notifier);

        final line = notifier.normalizeLineForTesting(
          'sabbe [apāṇakoṭikaṃ]',
          const {},
        );
        final term = normalizePaliFuzzy('apāṇakoṭikaṃ');
        expect(line.contains(term), isFalse);
      },
    );

    test('strip=false (variants shown): variant-only word is searchable', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier).state = AppSettings(
        stripVariantAnnotations: false,
      );
      final notifier = container.read(inBookSearchProvider.notifier);

      final line = notifier.normalizeLineForTesting(
        'sabbe [apāṇakoṭikaṃ]',
        const {},
      );
      final term = normalizePaliFuzzy('apāṇakoṭikaṃ');
      expect(line.contains(term), isTrue);
    });

    test('translation brackets are searchable in BOTH toggle states', () {
      // Translator additions like "[monks]" are not variant readings.
      for (final strip in [true, false]) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(settingsProvider.notifier).state = AppSettings(
          stripVariantAnnotations: strip,
        );
        final notifier = container.read(inBookSearchProvider.notifier);

        final line = notifier.normalizeLineForTesting('sabbe dhammā', const {
          'en': 'all [phenomena] are impermanent',
        });
        expect(
          line.contains(normalizePaliFuzzy('phenomena')),
          isTrue,
          reason: 'strip=$strip',
        );
      }
    });
  });
}

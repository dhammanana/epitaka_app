/// Regression tests for the "Show variant readings" toggle in the reader.
///
/// Pāli reading variants (bracketed spans like `[iti]` in the source DB)
/// are stripped by default. Toggling the setting in the settings screen
/// must take effect in the reader immediately.
///
/// The reader renders through [PaliTextWithVariants] and direct converter
/// calls, which only READ the shared `stripVariantAnnotations` global —
/// previously only [PaliText]/[PaliHtmlText] pushed that global, so the
/// reader never saw the toggle (the setting appeared to do nothing). The
/// fix pushes the flag from the reader's settings-watching ancestor
/// (ReaderContentList), exactly as this test's wrapper does.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/providers/settings_provider.dart';
import '../lib/core/utils/pali_script_converter.dart';
import '../lib/core/utils/pali_text_utils.dart';
import '../lib/shared/widgets/pali_text.dart';

/// Mirrors ReaderContentList: a settings-watching ancestor pushes the
/// variant-stripping flag before the reader renders Pāli lines.
class _ReaderLikeWrapper extends ConsumerWidget {
  const _ReaderLikeWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    stripVariantAnnotations = settings.stripVariantAnnotations;
    return PaliTextWithVariants(
      'evaṃ me sutaṃ [iti] ekaṃ samayaṃ',
      script: settings.paliScript,
      colors: Theme.of(context).colorScheme,
    );
  }
}

void main() {
  group('stripVariantAnnotations converter contract', () {
    tearDown(() => stripVariantAnnotations = true);

    test('true: variant segments are omitted', () {
      stripVariantAnnotations = true;
      final segments =
          convertPaliToScriptSegments('evaṃ [iti] sutaṃ', Script.roman);
      expect(segments.where((s) => s.isVariant), isEmpty);
      expect(segments.map((s) => s.text).join(' ').contains('iti'), isFalse);
    });

    test('false: variant segments are kept and flagged', () {
      stripVariantAnnotations = false;
      final segments =
          convertPaliToScriptSegments('evaṃ [iti] sutaṃ', Script.roman);
      final variants = segments.where((s) => s.isVariant).toList();
      expect(variants, hasLength(1));
      expect(variants.single.text, 'iti');
    });
  });

  group('reader rendering follows the settings toggle', () {
    Future<ProviderContainer> pumpWith(
      WidgetTester tester, {
      required bool strip,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier).state = AppSettings(
        stripVariantAnnotations: strip,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: const _ReaderLikeWrapper()),
          ),
        ),
      );
      return container;
    }

    testWidgets('enabled (strip=false): variant chip is shown', (tester) async {
      await pumpWith(tester, strip: false);
      // The variant renders as a chip labelled "variant".
      expect(find.text('variant'), findsOneWidget);
    });

    testWidgets('disabled (strip=true): variant is omitted', (tester) async {
      await pumpWith(tester, strip: true);
      expect(find.text('variant'), findsNothing);
    });

    testWidgets('toggling the setting mid-session re-renders the reader',
        (tester) async {
      final container = await pumpWith(tester, strip: true);
      expect(find.text('variant'), findsNothing);

      // A plain settings change (as the settings screen makes) must be
      // visible on the next frame — no app restart, no stop/start.
      await container
          .read(settingsProvider.notifier)
          .setStripVariantAnnotations(false);
      await tester.pump();
      expect(find.text('variant'), findsOneWidget);

      // And back.
      await container
          .read(settingsProvider.notifier)
          .setStripVariantAnnotations(true);
      await tester.pump();
      expect(find.text('variant'), findsNothing);
    });
  });
}

/// Probe: word extraction (getPositionForOffset → getWordBoundary) on full
/// converted Pali sentences, simulating taps across the rendered line.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/pali_script_converter.dart';
import '../lib/core/utils/pali_text_utils.dart';
import '../lib/core/utils/velthuis.dart';

void main() {
  const roman = 'namo tassa bhagavato arahato sammāsambuddhassa';

  Future<void> probe(
    WidgetTester tester,
    String label,
    Script script, {
    bool withSearchHighlight = false,
  }) async {
    final display = convertPaliToScript(roman, script);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            display,
            key: key,
            style: TextStyle(fontFamily: scriptFontFamily(script)),
          ),
        ),
      ),
    );
    final render = key.currentContext!.findRenderObject()! as RenderParagraph;
    final plain = render.text.toPlainText();
    final width = render.size.width;
    debugPrint(
      '=== $label (${script.name}): "$plain" width=${width.toStringAsFixed(1)} ===',
    );

    final seen = <String>{};
    // Walk x across the line in small steps, tap, and record the extracted word.
    for (double x = 1; x < width - 1; x += 4) {
      final pos = render.getPositionForOffset(Offset(x, 2));
      final b = render.getWordBoundary(pos);
      if (!b.isValid || b.isCollapsed) continue;
      final raw = plain.substring(b.start, b.end);
      final romanWord = convertToRomanPali(raw);
      final clean = romanWord
          .replaceAll(
            RegExp(r"[^\wāīūōṅñṭḍṇḷṃĀĪŪŌṄÑṬḌṆḶṀ\s]"),
            '',
          )
          .trim();
      final sig = '$raw → $clean';
      if (seen.add(sig)) {
        debugPrint('  x=${x.toStringAsFixed(0)} off=$pos $sig');
      }
    }
  }

  testWidgets('word extraction across scripts', (tester) async {
    await probe(tester, 'Tamil', Script.tamil);
    await probe(tester, 'Myanmar', Script.myanmar);
    await probe(tester, 'Thai', Script.thai);
    await probe(tester, 'Sinhala', Script.sinhala);
    await probe(tester, 'Roman', Script.roman);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/shared/utils/html_text_parser.dart';

void main() {
  test('probe: i wraps b, and b wraps i', () {
    const base = TextStyle(fontSize: 19);

    const cases = <String, (FontWeight?, FontStyle?)>{
      '<i>a<b>bb</b>c</i>': (FontWeight.w700, FontStyle.italic),
      '<b>a<i>bb</i>c</b>': (FontWeight.w700, FontStyle.italic),
      '<i><b>both</b></i>': (FontWeight.w700, FontStyle.italic),
      '<b><i>both</i></b>': (FontWeight.w700, FontStyle.italic),
    };

    for (final entry in cases.entries) {
      final html = entry.key;
      final spans = HtmlTextParser.parse(html, base);
      String dump() => spans
          .map((s) {
            final t = s as TextSpan;
            return '${t.text ?? ''}[w=${t.style?.fontWeight},'
                'i=${t.style?.fontStyle}]';
          })
          .join(' ');
      debugPrint('--- $html');
      debugPrint(dump());
      for (final s in spans) {
        final t = s as TextSpan;
        if (t.text != null && t.text!.trim().isNotEmpty) {
          expect(
            t.style?.fontWeight,
            entry.value.$1,
            reason: 'bold for "$html": ${dump()}',
          );
          expect(
            t.style?.fontStyle,
            entry.value.$2,
            reason: 'italic for "$html": ${dump()}',
          );
        }
      }
    }
  });
}

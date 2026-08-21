import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/utils/reader_word_hit_test.dart';

void main() {
  testWidgets('probe: hitTestWordAt on rendered Myanmar text', (tester) async {
    final contentKey = GlobalKey();

    // Line of Pali in Myanmar script, matching the app's rendering path.
    const myanmarLine = 'Namo tassa ဘဂဝတော arahato';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Listener(
            key: contentKey,
            child: SelectionArea(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(myanmarLine, style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ),
      ),
    );

    // Find the rendered Text widget and its global position.
    final textFinder = find.text(myanmarLine);
    expect(textFinder, findsOneWidget);
    final topLeft = tester.getTopLeft(textFinder);
    final size = tester.getSize(textFinder);
    // ignore: avoid_print
    print('PROBE text at $topLeft size $size');

    // Tap in the middle of the Myanmar word ဘဂဝတော. The word starts at
    // index 11 in the string; approximate its x-center: tap at the center
    // of the whole line minus a bit (words are roughly equal width).
    // Try several x offsets to be sure one lands inside the Myanmar word.
    final lineCenterY = topLeft.dy + size.height / 2;
    for (final frac in [0.42, 0.5, 0.55, 0.6, 0.65, 0.7]) {
      final pos = Offset(topLeft.dx + size.width * frac, lineCenterY);
      final hit = hitTestWordAt(contentKey, pos);
      // ignore: avoid_print
      print(
        'PROBE hitTest at x=$frac -> '
        '${hit != null ? 'word="${hit.word}" raw="${hit.rawWord}"' : 'null'}',
      );
    }
  });
}

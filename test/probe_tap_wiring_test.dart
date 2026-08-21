import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/settings_provider.dart'
    show WordLookupGesture;
import 'package:epitaka/features/reader/providers/reader_dictionary_lookup_controller.dart';
import 'package:epitaka/features/reader/utils/reader_word_hit_test.dart';

void main() {
  testWidgets('probe: single tap on Myanmar text through real wiring', (
    tester,
  ) async {
    final contentKey = GlobalKey();
    final controller = ReaderDictionaryLookupController();
    controller.gesture = WordLookupGesture.singleTap;

    String? lookedUpWord;
    ReaderWordHitResult? lookedUpHit;

    const myanmarLine = 'Namo tassa ဘဂဝတော arahato';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Listener(
            key: contentKey,
            onPointerDown: (e) {
              final r = controller.handlePointerDown(
                pointer: e.pointer,
                localPosition: e.localPosition,
                globalPosition: e.position,
                timestampMs: e.timeStamp.inMilliseconds,
                contentHitTestKey: contentKey,
              );
              if (r.shouldLookup) {
                lookedUpWord = r.word;
                lookedUpHit = r.hit;
              }
            },
            onPointerUp: (e) {
              final r = controller.handlePointerUp(
                pointer: e.pointer,
                globalPosition: e.position,
                timestampMs: e.timeStamp.inMilliseconds,
                contentHitTestKey: contentKey,
                hasSelection: false,
              );
              if (r.shouldLookup) {
                lookedUpWord = r.word;
                lookedUpHit = r.hit;
              }
            },
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

    final textFinder = find.text(myanmarLine);
    final topLeft = tester.getTopLeft(textFinder);
    final size = tester.getSize(textFinder);

    // Tap at the center of the Myanmar word (x=0.55 of the line).
    final tapPos = Offset(
      topLeft.dx + size.width * 0.55,
      topLeft.dy + size.height / 2,
    );
    // ignore: avoid_print
    print('PROBE tapping at $tapPos');
    await tester.tapAt(tapPos);
    await tester.pump();

    // ignore: avoid_print
    print(
      'PROBE lookedUpWord=$lookedUpWord '
      'hit=${lookedUpHit != null ? '${lookedUpHit!.word}/${lookedUpHit!.rawWord}' : 'null'}',
    );
  });
}

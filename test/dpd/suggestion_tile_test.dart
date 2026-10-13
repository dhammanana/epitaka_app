/// Suggestion rows draw at one size, whether or not the typed letters appear
/// in the word. A folded match (`satthipada` for `satip`) has no highlight, an
/// exact one does; both must follow the app's text scale.
library;

import 'package:epitaka/features/dictionary/widgets/dictionary_search_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('highlighted and plain rows have the same height at text scale 1.5', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const colors = ColorScheme.light();
    Widget tile(String word) => SuggestionTile(
      word: word,
      onTap: () {},
      colors: colors,
      highlightQuery: 'satip',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: Column(
                children: [
                  KeyedSubtree(key: const Key('plain'), child: tile('satthipada')),
                  KeyedSubtree(key: const Key('match'), child: tile('satiphāle')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final plain = tester.getSize(find.byKey(const Key('plain'))).height;
    final match = tester.getSize(find.byKey(const Key('match'))).height;
    expect(match, plain);
  });
}

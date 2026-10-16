/// A word tap must reach the search without a second click. The lookup runs
/// in a post-frame callback, which does not schedule a frame by itself.
library;

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/dpd/widgets/tap_search_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a tap schedules the frame that runs the lookup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(settingsProvider.notifier)
        .init(await SharedPreferences.getInstance());
    container
        .read(settingsProvider.notifier)
        .setWordLookupGesture(WordLookupGesture.singleTap);

    final words = <String>[];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TapSearchWrapper(
              onWordTap: words.add,
              child: const Center(child: Text('agathito')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('agathito'));
    // No pump yet: this is the moment after a click on desktop.
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump();
    expect(words, ['agathito']);
  });
}

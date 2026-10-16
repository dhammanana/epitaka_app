import 'package:epitaka/app.dart';
import 'package:epitaka/core/utils/app_initializer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    AppInitializer.skipSupabaseInit = true;
    addTearDown(() => AppInitializer.skipSupabaseInit = false);

    await tester.pumpWidget(const ProviderScope(child: EpitakaApp()));
    await tester.pump();

    // The app must boot into a usable scaffold without throwing. On first
    // frames the IndexGate shows its loading screen (or the setup wizard,
    // since no search index exists in a test) before the real shell
    // (desktop reader / mobile library) appears — so assert on the scaffold
    // + absence of exceptions rather than on any single screen's text.
    expect(find.byType(Scaffold), findsWidgets);

    // The index check waits on a real platform call that never returns in a
    // test, so it ends on its 2-minute timeout. Run that out on the fake
    // clock so no timer is left pending.
    await tester.pump(const Duration(minutes: 2));
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

import 'package:epitaka/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EpitakaApp()));
    await tester.pump();

    // The app must boot into a usable scaffold without throwing. On first
    // frames the IndexGate shows its loading screen (or the setup wizard,
    // since no search index exists in a test) before the real shell
    // (desktop reader / mobile library) appears — so assert on the scaffold
    // + absence of exceptions rather than on any single screen's text.
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

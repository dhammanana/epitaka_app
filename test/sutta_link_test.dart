import 'dart:async';

import 'package:epitaka/features/deep_links/deep_link_service.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/sutta_jump/widgets/go_to_sutta_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/sutta_link_harness.dart';

// Rows are copied from the real epitaka.db: an4.126 is A-iv paragraph 1114.
void main() {
  Future<void> closeBox(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(GoToSuttaDialog), findsNothing);
  }

  testWidgets('a sutta link after launch opens the sutta in a reader tab', (
    tester,
  ) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    final container = await pumpSuttaLinkApp(tester, db);

    DeepLinkService.instance.handleUri(
      Uri.parse('epitaka://sutta?code=an4.126'),
    );
    await settleLink(tester);

    final tab = container.read(readerTabsProvider).activeTab!;
    expect((tab.bookId, tab.initialParaId), ('A-iv', 1114));
    expect(tab.bookName, 'AN4-Catukkanipātapāḷi');
    expect(container.read(readerTabsProvider).tabs, hasLength(1));
  });

  testWidgets('the code may be in any case', (tester) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    final container = await pumpSuttaLinkApp(tester, db);

    DeepLinkService.instance.handleUri(
      Uri.parse('epitaka://sutta?code=THAG1.1'),
    );
    await settleLink(tester);

    expect(container.read(readerTabsProvider).activeTab!.bookId, 'Th');
  });

  testWidgets('a sutta link kept before the screens exist runs once they '
      'appear', (tester) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    final gate = ValueNotifier(false);
    final container = await pumpSuttaLinkApp(tester, db, gateOpen: gate);

    DeepLinkService.instance.handleUri(
      Uri.parse('epitaka://sutta?code=an4.126'),
    );
    await settleLink(tester);
    expect(container.read(readerTabsProvider).tabs, isEmpty);

    gate.value = true;
    await settleLink(tester);

    final tabs = container.read(readerTabsProvider).tabs;
    expect(tabs, hasLength(1));
    expect((tabs.single.bookId, tabs.single.initialParaId), ('A-iv', 1114));
  });

  testWidgets('a code with no sutta opens the box with the code typed in', (
    tester,
  ) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    final container = await pumpSuttaLinkApp(tester, db);

    DeepLinkService.instance.handleUri(Uri.parse('epitaka://sutta?code=ud1'));
    await settleLink(tester);

    expect(find.byType(GoToSuttaDialog), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'ud1');
    expect(find.textContaining('No sutta found'), findsOneWidget);
    expect(container.read(readerTabsProvider).tabs, isEmpty);
    await closeBox(tester);
  });

  testWidgets('a link code that matches no code does not run the name scan', (
    tester,
  ) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    await pumpSuttaLinkApp(tester, db);
    final context = tester.element(find.text('home'));

    // A heading name: the box finds it by name when typed, but a link's code
    // is searched as a code only.
    unawaited(showGoToSuttaDialog(context, initialText: 'dutiyamettasuttam'));
    await settleLink(tester);

    expect(find.textContaining('No sutta found'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
    await closeBox(tester);
  });

  testWidgets('the website form opens the sutta, not a book named sutta', (
    tester,
  ) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    final container = await pumpSuttaLinkApp(tester, db);

    DeepLinkService.instance.handleUri(
      Uri.parse('https://epitaka.org/app/sutta?code=an4.126'),
    );
    await settleLink(tester);

    final tabs = container.read(readerTabsProvider).tabs;
    expect(tabs.map((t) => t.bookId), ['A-iv']);
  });

  testWidgets('the box opens with a code already searched, and a second open '
      'while it is showing does nothing', (tester) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    await pumpSuttaLinkApp(tester, db);
    final context = tester.element(find.text('home'));

    unawaited(showGoToSuttaDialog(context, initialText: 'an4.126'));
    await settleLink(tester);
    expect(find.textContaining('AN4.126 · '), findsOneWidget);

    unawaited(showGoToSuttaDialog(context, initialText: 'an4.125'));
    await settleLink(tester);
    expect(find.byType(GoToSuttaDialog), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'an4.126');
    await closeBox(tester);
  });
}

import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/shared/widgets/history_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {ThemeData? theme, double? height}) => MaterialApp(
  theme: theme,
  supportedLocales: AppLocalizationsDelegate.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: SizedBox(height: height, child: child),
  ),
);

HistoryItem item(String t, {VoidCallback? onTap, VoidCallback? onDelete}) =>
    HistoryItem(
      key: t,
      title: Text(t),
      onTap: onTap ?? () {},
      onDelete: onDelete,
    );

Future<void> pumpIt(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  await t.pump();
}

void main() {
  testWidgets('empty draws nothing', (tester) async {
    await pumpIt(tester, host(const HistoryList(items: [], title: 'x')));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('rows come in order, tap calls onTap', (tester) async {
    var tapped = '';
    await pumpIt(
      tester,
      host(
        HistoryList(
          items: [
            item('a', onTap: () => tapped = 'a'),
            item('b', onTap: () => tapped = 'b'),
          ],
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('a')).dy <
          tester.getTopLeft(find.text('b')).dy,
      isTrue,
    );
    await tester.tap(find.text('b'));
    expect(tapped, 'b');
  });

  testWidgets('X calls onDelete and not onTap; no X without onDelete', (
    tester,
  ) async {
    var tapped = 0, deleted = 0;
    await pumpIt(
      tester,
      host(
        HistoryList(
          items: [
            item('a', onTap: () => tapped++, onDelete: () => deleted++),
            item('b'),
          ],
        ),
      ),
    );
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deleted, 1);
    expect(tapped, 0);
  });

  testWidgets('Clear shows only with onClear', (tester) async {
    await pumpIt(
      tester,
      host(HistoryList(items: [item('a')], title: 'Recent searches')),
    );
    expect(find.text('Clear history'), findsNothing);
    var cleared = false;
    await pumpIt(
      tester,
      host(
        HistoryList(
          items: [item('a')],
          title: 'Recent searches',
          onClear: () => cleared = true,
        ),
      ),
    );
    await tester.tap(find.text('Clear history'));
    expect(cleared, isTrue);
  });

  testWidgets('selectedIndex row has the tint', (tester) async {
    await pumpIt(
      tester,
      host(HistoryList(items: [item('a'), item('b')], selectedIndex: 1)),
    );
    final primary = Theme.of(
      tester.element(find.text('a')),
    ).colorScheme.primaryContainer;
    Color? colorOf(String t) => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byKey(ValueKey(t)),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;
    expect(colorOf('b'), primary);
    expect(colorOf('a'), isNot(primary));
  });

  testWidgets('40 items scroll inside 300 px without overflow, dark theme', (
    tester,
  ) async {
    await pumpIt(
      tester,
      host(
        Column(
          children: [
            Expanded(
              child: HistoryList(
                title: 'Recent searches',
                items: [for (var i = 0; i < 40; i++) item('w$i')],
              ),
            ),
          ],
        ),
        theme: ThemeData.dark(),
        height: 300,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('w39'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump();
    expect(find.text('w39'), findsOneWidget);
  });
}

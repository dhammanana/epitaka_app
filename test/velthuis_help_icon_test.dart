import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';

Future<TextEditingController> _pumpField(
  WidgetTester tester, {
  bool sanskrit = true,
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 100),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                suffixIcon: VelthuisHelpIcon(sanskrit: sanskrit),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // The string tables load asynchronously; the field appears a frame later.
  await tester.pump();
  return controller;
}

/// The card is one rich text: the title line, then one line per rule.
Finder _card() => find.textContaining('Velthuis typing', findRichText: true);

void main() {
  test('the card lists the lowercase Pāli rules, then the Sanskrit ones', () {
    expect(
      [for (final (from, _) in VelthuisHelpIcon.rows) from],
      ['aa', 'ii', 'uu', '"n', '~n', '.t', '.d', '.n', '.m', '.l'],
    );
    expect(
      [for (final (from, _) in VelthuisHelpIcon.sanskritRows) from],
      ['"s', '.s', '.r', '.rr', '.ll', '.h'],
    );
  });

  testWidgets('pointing at the icon shows the card at once; leaving hides it',
      (tester) async {
    await _pumpField(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);

    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.help_outline)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_card(), findsOneWidget);
    final text = tester.widget<RichText>(_card()).text.toPlainText();
    expect(text, contains('.m   →  ṃ'));
    expect(text, contains('.rr  →  ṝ'));
    expect(text, contains('aaa  →  aa\niii  →  ii\nuuu  →  uu'));
    expect(text.indexOf('Sanskrit'), greaterThan(text.indexOf('.l   →  ḷ')),
        reason: 'the Sanskrit rows sit under the Pāli rows');

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(_card(), findsNothing);
  });

  testWidgets('with Sanskrit off the card has no Sanskrit section',
      (tester) async {
    await _pumpField(tester, sanskrit: false);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.help_outline)));
    await tester.pump(const Duration(milliseconds: 200));

    final text = tester.widget<RichText>(_card()).text.toPlainText();
    expect(text, contains('.m   →  ṃ'));
    expect(text, contains('aaa  →  aa\niii  →  ii\nuuu  →  uu'));
    expect(text, isNot(contains('Sanskrit')));
    expect(text, isNot(contains('.rr')));
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('a tap shows the card; the field keeps focus and typing works',
      (tester) async {
    final controller = await _pumpField(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_card(), findsOneWidget);

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'dhamma');
    expect(controller.text, 'dhamma');

    // Let the 10 s show time run out so no timer outlives the test.
    await tester.pumpAndSettle(const Duration(seconds: 11));
  });

  testWidgets('on desktop, pointing at the icon while typing keeps the cursor',
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
      (tester) async {
    final controller = await _pumpField(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final field = tester.getCenter(find.byType(TextField));
    await mouse.moveTo(field);
    await mouse.down(field);
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 500));

    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.help_outline)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_card(), findsOneWidget);

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'dhamma');
    expect(controller.text, 'dhamma');
  });
}

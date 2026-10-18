import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Types [keys] into [field] one key at a time, after the text it already
/// holds, as a keyboard does. `enterText` alone sets the whole text in one
/// edit, which the Velthuis formatter treats as a paste and leaves alone.
Future<void> typeKeys(WidgetTester tester, Finder field, String keys) async {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
    matchRoot: true,
  );
  for (final key in keys.split('')) {
    final text = tester.widget<EditableText>(editable.first).controller.text;
    await tester.enterText(field, text + key);
  }
}

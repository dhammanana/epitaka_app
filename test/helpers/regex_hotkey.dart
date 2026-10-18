import 'package:epitaka/shared/utils/app_shortcuts.dart';
import 'package:epitaka/shared/widgets/regex_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// [child] under the app's real shortcut bindings, as app.dart puts them
/// above MaterialApp. Needs a ProviderScope above it.
Widget withAppShortcuts(Widget child) => Consumer(
  builder: (context, ref, child) => CallbackShortcuts(
    bindings: AppShortcuts.bindings(GlobalKey<NavigatorState>(), ref),
    child: child!,
  ),
  child: child,
);

/// Whether the Rx button inside [field] is on.
bool rxOnIn(WidgetTester tester, Finder field) => tester
    .widget<RegexToggleButton>(
      find.descendant(of: field, matching: find.byType(RegexToggleButton)),
    )
    .on;

/// Whether the cursor is in [field].
bool fieldHasFocus(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

/// Puts the cursor in [field] and runs the action the Alt+R shortcut
/// ('regex-toggle') runs. The real key, through [withAppShortcuts], is
/// pressed in the Contents panel, the dictionary and Go to Sutta tests.
Future<void> regexHotkeyIn(WidgetTester tester, Finder field) async {
  await tester.showKeyboard(field);
  toggleRegexInFocusedBox();
}

/// Presses Alt+R as a keyboard sends it.
Future<void> sendAltR(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
}

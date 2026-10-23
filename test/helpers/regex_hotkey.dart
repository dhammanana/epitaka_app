import 'package:epitaka/shared/utils/app_shortcuts.dart';
import 'package:epitaka/shared/widgets/search_box_actions.dart';
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

/// The suffix of [field]: the widget that holds the clear button and the
/// "more" menu, and answers for the box's regex state.
SearchBoxSuffixActions suffixIn(WidgetTester tester, Finder field) =>
    tester.widget<SearchBoxSuffixActions>(
      find.descendant(of: field, matching: find.byType(SearchBoxSuffixActions)),
    );

/// Whether the "more" menu of [field] would show the regex item checked.
bool rxOnIn(WidgetTester tester, Finder field) => suffixIn(tester, field).regexOn;

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

/// Opens the "more" menu of [field] and taps the menu item [label], then
/// lets the menu close again. The item itself opens (the Velthuis card runs
/// in a dialog), which the caller settles separately.
Future<void> tapMoreItemIn(WidgetTester tester, Finder field, String label) =>
    _tapItem(tester, find.descendant(of: field, matching: find.byIcon(Icons.more_vert)), label);

/// Taps the regex item of [field]'s "more" menu: the tap path of the
/// Alt+R toggle (the hotkey itself is [regexHotkeyIn]). The menu opens,
/// the toggle runs, the menu closes.
Future<void> regexToggleByTapIn(WidgetTester tester, Finder field) =>
    _tapItem(tester, find.descendant(of: field, matching: find.byIcon(Icons.more_vert)), 'Regular expression');

/// Opens the "more" menu of [field] and taps the Velthuis help item, then
/// settles the help dialog it opens. Returns with the dialog showing.
Future<void> openVelthuisHelpIn(WidgetTester tester, Finder field) async {
  await _tapItem(
    tester,
    find.descendant(of: field, matching: find.byIcon(Icons.more_vert)),
    'Velthuis typing',
  );
  await tester.pumpAndSettle();
}

/// Closes the open "more" menu (or the dialog it opened) with Esc, so the
/// next assertion finds the search box alone. A tap route closes the menu,
/// but where the menu lands differs per box; the key works everywhere.
Future<void> closeMoreMenu(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

Future<void> _tapItem(WidgetTester tester, Finder menuButton, String label) async {
  await tester.tap(menuButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Presses Alt+R as a keyboard sends it.
Future<void> sendAltR(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
}

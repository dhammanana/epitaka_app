import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/models/toolbar_item.dart';
import 'package:epitaka/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default toolbar items: every built-in, enabled, in default order',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);
    notifier.init(prefs);

    final ids = notifier.state.toolbarItems.map((i) => i.id).toList();
    expect(ids, equals(ToolbarBuiltins.defaults));
    expect(notifier.state.toolbarItems.every((i) => i.enabled), isTrue);
  });

  test('saved toolbar from older version gets missing built-ins merged in',
      () async {
    // A config saved before contents/outline/search/dictionary/annotations
    // existed: only the core actions are present, one disabled.
    SharedPreferences.setMockInitialValues({
      'toolbar_items': jsonEncode([
        ToolbarItem(id: ToolbarBuiltins.listen, enabled: false),
        ToolbarItem(id: ToolbarBuiltins.bookmark),
      ].map((i) => i.toJson()).toList()),
    });

    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);
    notifier.init(prefs);

    final items = notifier.state.toolbarItems;
    final ids = items.map((i) => i.id).toList();

    // New built-ins must appear, enabled by default.
    expect(ids, contains(ToolbarBuiltins.contents));
    expect(ids, contains(ToolbarBuiltins.annotations));
    final contents = items.firstWhere((i) => i.id == ToolbarBuiltins.contents);
    expect(contents.enabled, isTrue);

    // The user's original order and toggles are preserved at the front.
    expect(ids.take(2), [ToolbarBuiltins.listen, ToolbarBuiltins.bookmark]);
    expect(items.first.enabled, isFalse);

    // No duplication when everything is already present.
    SharedPreferences.setMockInitialValues({
      'toolbar_items': jsonEncode(
        defaultToolbarItems().map((i) => i.toJson()).toList(),
      ),
    });
    final completePrefs = await SharedPreferences.getInstance();
    final completeNotifier = SettingsNotifier(completePrefs);
    completeNotifier.init(completePrefs);
    final completeIds =
        completeNotifier.state.toolbarItems.map((i) => i.id).toList();
    expect(completeIds, hasLength(ToolbarBuiltins.defaults.length));
    expect(completeIds.toSet(), hasLength(ToolbarBuiltins.defaults.length));
  });

  test('reorder and toggle persist across reload', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);
    notifier.init(prefs);

    // Reorder: move bookmark to the front, disable dictionary.
    final reordered = [
      ToolbarItem(id: ToolbarBuiltins.bookmark),
      ToolbarItem(id: ToolbarBuiltins.dictionary, enabled: false),
      ...notifier.state.toolbarItems
          .where((i) => i.id != ToolbarBuiltins.bookmark &&
              i.id != ToolbarBuiltins.dictionary),
    ];
    await notifier.setToolbarItems(reordered);
    await notifier.setToolbarItemEnabled(ToolbarBuiltins.listen, false);

    // Reload from the same prefs — the config must round-trip.
    final reloaded = SettingsNotifier(prefs);
    reloaded.init(prefs);
    final items = reloaded.state.toolbarItems;
    final ids = items.map((i) => i.id).toList();

    expect(ids.first, ToolbarBuiltins.bookmark);
    expect(ids, hasLength(ToolbarBuiltins.defaults.length));
    expect(
      items.firstWhere((i) => i.id == ToolbarBuiltins.dictionary).enabled,
      isFalse,
    );
    expect(
      items.firstWhere((i) => i.id == ToolbarBuiltins.listen).enabled,
      isFalse,
    );
  });

  test('resetToolbarItems resets items to defaults and default display order',
      () async {
    SharedPreferences.setMockInitialValues({
      'toolbar_items': jsonEncode([
        ToolbarItem(id: ToolbarBuiltins.annotations, enabled: false),
        ToolbarItem(id: ToolbarBuiltins.jump),
      ].map((i) => i.toJson()).toList()),
    });

    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);
    notifier.init(prefs);

    await notifier.resetToolbarItems();

    final resetIds = notifier.state.toolbarItems.map((i) => i.id).toList();
    expect(resetIds, equals(ToolbarBuiltins.defaults));
    expect(notifier.state.toolbarItems.every((i) => i.enabled), isTrue);
  });
}

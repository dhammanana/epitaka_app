import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/models/context_menu_action.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/native_speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved context menu from older version gets highlight/note/lookUp/speak merged in',
      () async {
    // A config saved before highlight/note/lookUp/speak existed: only the legacy
    // built-ins are present.
    SharedPreferences.setMockInitialValues({
      'context_menu_actions': jsonEncode([
        ContextMenuAction(
          id: 'builtin:copy',
          kind: ContextMenuActionKind.builtin,
          builtinId: ContextMenuBuiltins.copy,
        ),
        ContextMenuAction(
          id: 'builtin:dictionary',
          kind: ContextMenuActionKind.builtin,
          builtinId: ContextMenuBuiltins.dictionary,
        ),
      ].map((a) => a.toJson()).toList()),
    });

    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);
    notifier.init(prefs);

    final actions = notifier.state.contextMenuActions;
    final builtinIds =
        actions.where((a) => a.builtinId != null).map((a) => a.builtinId).toList();

    // New built-ins must appear, enabled by default.
    expect(builtinIds, contains(ContextMenuBuiltins.highlight));
    expect(builtinIds, contains(ContextMenuBuiltins.note));
    expect(builtinIds, contains(ContextMenuBuiltins.lookUp));
    expect(builtinIds, contains(ContextMenuBuiltins.speak));
    final highlight = actions.firstWhere(
      (a) => a.builtinId == ContextMenuBuiltins.highlight,
    );
    expect(highlight.enabled, isTrue);
    final lookUp = actions.firstWhere(
      (a) => a.builtinId == ContextMenuBuiltins.lookUp,
    );
    expect(lookUp.enabled, isTrue);
    final speak = actions.firstWhere(
      (a) => a.builtinId == ContextMenuBuiltins.speak,
    );
    expect(speak.enabled, isTrue);

    // The user's original order and toggles are preserved at the front.
    expect(builtinIds.take(2), [
      ContextMenuBuiltins.copy,
      ContextMenuBuiltins.dictionary,
    ]);

    // Defaults only — no duplication when everything is already present.
    SharedPreferences.setMockInitialValues({
      'context_menu_actions': jsonEncode(
        defaultContextMenuActions().map((a) => a.toJson()).toList(),
      ),
    });
    final completePrefs = await SharedPreferences.getInstance();
    final completeNotifier = SettingsNotifier(completePrefs);
    completeNotifier.init(completePrefs);
    final completeIds = completeNotifier.state.contextMenuActions
        .where((a) => a.builtinId != null)
        .map((a) => a.builtinId)
        .toList();
    expect(completeIds, hasLength(ContextMenuBuiltins.defaults.length));
    expect(completeIds.toSet(), hasLength(ContextMenuBuiltins.defaults.length));
    expect(completeIds, contains(ContextMenuBuiltins.speak));
  });

  test('resetContextMenuActions resets actions to defaults and default display order',
      () async {
    SharedPreferences.setMockInitialValues({
      'context_menu_actions': jsonEncode([
        ContextMenuAction(
          id: 'builtin:share',
          kind: ContextMenuActionKind.builtin,
          builtinId: ContextMenuBuiltins.share,
          enabled: false,
        ),
      ].map((a) => a.toJson()).toList()),
    });

    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);
    notifier.init(prefs);

    // Reset to defaults
    await notifier.resetContextMenuActions();

    final resetActions = notifier.state.contextMenuActions;
    final resetBuiltinIds = resetActions
        .where((a) => a.builtinId != null)
        .map((a) => a.builtinId)
        .toList();

    expect(resetBuiltinIds, equals(ContextMenuBuiltins.defaults));
    expect(resetActions.every((a) => a.enabled), isTrue);
  });

  test('NativeSpeechService returns false on empty text or unsupported platforms', () async {
    final result = await NativeSpeechService.speak('');
    expect(result, isFalse);
    final whitespaceResult = await NativeSpeechService.speak('   ');
    expect(whitespaceResult, isFalse);
  });
}

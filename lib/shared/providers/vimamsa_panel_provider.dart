import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the Vimaṃsa (AI assistant) center tab is the visible one in the
/// desktop shell.
///
/// Kept in a provider (instead of local state inside [DesktopShell]) so the
/// global keyboard shortcut (Cmd/Ctrl+Shift+V) and the reader keyboard
/// navigation can toggle / react to it without reaching into the shell's
/// private state.
class VimamsaOpenNotifier extends StateNotifier<bool> {
  VimamsaOpenNotifier() : super(false);

  void toggle() => state = !state;

  void open() => state = true;

  void close() => state = false;
}

final vimamsaOpenProvider =
    StateNotifierProvider<VimamsaOpenNotifier, bool>((ref) {
      return VimamsaOpenNotifier();
    });

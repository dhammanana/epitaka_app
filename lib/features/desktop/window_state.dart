import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const _kStateKey = 'window_state';
const _kBoundsKey = 'window_bounds';

String encodeBounds(Rect bounds) => jsonEncode({
      'x': bounds.left,
      'y': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
    });

/// Returns null for bad data, and for a size too small to use, so the app
/// falls back to its default window.
Rect? decodeBounds(String? raw) {
  if (raw == null) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final bounds = Rect.fromLTWH(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
      (map['width'] as num).toDouble(),
      (map['height'] as num).toDouble(),
    );
    if (bounds.width < 400 || bounds.height < 300) return null;
    return bounds;
  } catch (e) {
    developer.log('Ignoring unreadable window bounds: $e',
        name: 'epitaka.window');
    return null;
  }
}

/// Only sets the window, never asks it for its state, so nothing here waits
/// on a window that is not shown yet.
Future<void> restoreWindowState(SharedPreferences prefs) async {
  await windowManager.ensureInitialized();
  final bounds = decodeBounds(prefs.getString(_kBoundsKey));
  // Bounds go first so that leaving maximized returns to the saved size.
  if (bounds != null) await windowManager.setBounds(bounds);
  switch (prefs.getString(_kStateKey)) {
    case 'fullscreen':
      await windowManager.setFullScreen(true);
    case 'maximized':
      await windowManager.maximize();
  }
}

class WindowStateSaver with WindowListener {
  WindowStateSaver(this._prefs);

  final SharedPreferences _prefs;
  Timer? _boundsTimer;

  void _saveMode(String mode) {
    _prefs.setString(_kStateKey, mode).catchError((Object e) {
      developer.log('Could not save window state: $e', name: 'epitaka.window');
      return false;
    });
  }

  @override
  void onWindowMaximize() => _saveMode('maximized');

  @override
  void onWindowUnmaximize() => _saveMode('normal');

  @override
  void onWindowEnterFullScreen() => _saveMode('fullscreen');

  // Leaving full screen into a maximized window sends no maximize event.
  @override
  void onWindowLeaveFullScreen() => unawaited(_saveModeAfterFullScreen());

  Future<void> _saveModeAfterFullScreen() async {
    try {
      final maximized = await windowManager.isMaximized();
      _saveMode(maximized ? 'maximized' : 'normal');
    } catch (e) {
      developer.log('Could not read window state: $e', name: 'epitaka.window');
    }
  }

  // Linux sends resize and move on every layout pass, so wait for a pause.
  @override
  void onWindowResize() => _scheduleBoundsSave();

  @override
  void onWindowMove() => _scheduleBoundsSave();

  void _scheduleBoundsSave() {
    _boundsTimer?.cancel();
    _boundsTimer = Timer(const Duration(milliseconds: 500), saveBounds);
  }

  /// Keeps the normal window's bounds: a maximized, full-screen or minimized
  /// window would overwrite the size to return to.
  Future<void> saveBounds() async {
    try {
      if (await windowManager.isMaximized() ||
          await windowManager.isFullScreen() ||
          await windowManager.isMinimized()) {
        return;
      }
      final bounds = await windowManager.getBounds();
      await _prefs.setString(_kBoundsKey, encodeBounds(bounds));
    } catch (e) {
      developer.log('Could not save window bounds: $e', name: 'epitaka.window');
    }
  }
}

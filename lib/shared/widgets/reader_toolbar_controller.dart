import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Provides the [ReaderToolbarController] to the widget subtree inside the
/// desktop shell's docking area.
///
/// The reader screen looks this up during build and registers its toolbar
/// action handlers into the controller, so the attached status bar can drive
/// the same actions. Mobile never creates this scope, so the reader keeps its
/// floating pill toolbar untouched there.
class ReaderToolbarScope extends InheritedWidget {
  final ReaderToolbarController controller;

  const ReaderToolbarScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static ReaderToolbarScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ReaderToolbarScope>();
  }

  @override
  bool updateShouldNotify(ReaderToolbarScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

/// Bridges the desktop status bar to the active [ReaderScreen]'s toolbar
/// actions.
///
/// The reader registers its action handlers (contents, search, dictionary,
/// jump, display layout, TTS, bookmark) into this controller whenever the
/// active tab changes; the status bar reads them back and renders the
/// buttons. This keeps the actual toolbar logic inside [ReaderScreen]
/// (single source of truth) while letting the shell's status bar act on it.
class ReaderToolbarController extends ChangeNotifier {
  /// Whether a book is currently open in the reader (buttons enabled).
  bool enabled = false;

  VoidCallback? onContents;
  VoidCallback? onSearch;
  VoidCallback? onDictionary;
  VoidCallback? onJump;
  VoidCallback? onDisplayLayout;
  VoidCallback? onListen;
  VoidCallback? onStop;
  VoidCallback? onBookmark;
  VoidCallback? onAiAsk;

  /// TTS transport actions while a reading session is active, so the
  /// desktop status bar can host the transport controls (the floating
  /// chip is hidden inside the desktop shell).
  VoidCallback? onTtsPrev;
  VoidCallback? onTtsPlayPause;
  VoidCallback? onTtsNext;
  VoidCallback? onTtsFollow;
  VoidCallback? onTtsMore;

  bool _disposed = false;
  bool _notifyPending = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notifySafe() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Registers the current set of action handlers.
  ///
  /// Called by [ReaderScreen] during build. Only notifies listeners when the
  /// enabled flag or any handler identity changed, so the status bar doesn't
  /// rebuild on every reader rebuild. A notify that lands mid-build is
  /// deferred to the next frame so the listening status bar is never marked
  /// dirty during the build phase.
  void update({
    required bool enabled,
    VoidCallback? onContents,
    VoidCallback? onSearch,
    VoidCallback? onDictionary,
    VoidCallback? onJump,
    VoidCallback? onDisplayLayout,
    VoidCallback? onListen,
    VoidCallback? onStop,
    VoidCallback? onBookmark,
    VoidCallback? onAiAsk,
    VoidCallback? onTtsPrev,
    VoidCallback? onTtsPlayPause,
    VoidCallback? onTtsNext,
    VoidCallback? onTtsFollow,
    VoidCallback? onTtsMore,
  }) {
    final changed =
        enabled != this.enabled ||
        onContents != this.onContents ||
        onSearch != this.onSearch ||
        onDictionary != this.onDictionary ||
        onJump != this.onJump ||
        onDisplayLayout != this.onDisplayLayout ||
        onListen != this.onListen ||
        onStop != this.onStop ||
        onBookmark != this.onBookmark ||
        onAiAsk != this.onAiAsk ||
        onTtsPrev != this.onTtsPrev ||
        onTtsPlayPause != this.onTtsPlayPause ||
        onTtsNext != this.onTtsNext ||
        onTtsFollow != this.onTtsFollow ||
        onTtsMore != this.onTtsMore;
    this.enabled = enabled;
    this.onContents = onContents;
    this.onSearch = onSearch;
    this.onDictionary = onDictionary;
    this.onJump = onJump;
    this.onDisplayLayout = onDisplayLayout;
    this.onListen = onListen;
    this.onStop = onStop;
    this.onBookmark = onBookmark;
    this.onAiAsk = onAiAsk;
    this.onTtsPrev = onTtsPrev;
    this.onTtsPlayPause = onTtsPlayPause;
    this.onTtsNext = onTtsNext;
    this.onTtsFollow = onTtsFollow;
    this.onTtsMore = onTtsMore;
    if (!changed) return;
    // [ReaderScreen] registers handlers synchronously inside build, so a
    // first registration (or an enabled flip) can land mid-build while the
    // status bar's ListenableBuilder is also building. Notifying
    // synchronously then throws "setState() called during build", so defer
    // to the next frame (coalescing repeat updates into one notify).
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyPending) return;
      _notifyPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyPending = false;
        _notifySafe();
      });
      return;
    }
    notifyListeners();
  }

  /// Clears all handlers (e.g. when no book is open).
  void clear() {
    update(enabled: false);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The types of panels that can be shown in the sidebars.
enum SidePanelType {
  /// Table of contents for the currently open book.
  contents,

  /// Dictionary lookup panel.
  dictionary,

  /// Global search panel.
  search,

  /// Left panel: library browser / navigation.
  library,

  /// Gavesana (AI-powered search) panel.
  gavesana,
}

/// Which slot a panel occupies.
enum PanelSlot {
  /// Left sidebar slot (TOC, search, library).
  left,

  /// Right sidebar slot (dictionary, AI assistant).
  right,
}

/// State for a single sidebar slot (left or right).
class SidePanelState {
  /// The currently open panel type, or null if collapsed.
  final SidePanelType? openPanel;

  /// Whether the panel is pinned (locked open).
  final bool isPinned;

  /// The width of this panel in pixels.
  final double width;

  /// Optional data to pass to the panel (e.g. dictionary word).
  final String? panelData;

  /// When true, the panel should request focus on its primary text input
  /// as soon as it is shown (used by keyboard shortcuts like Cmd+D / Cmd+Shift+F).
  final bool autoFocus;

  const SidePanelState({
    this.openPanel,
    this.isPinned = false,
    this.width = 340,
    this.panelData,
    this.autoFocus = false,
  });

  SidePanelState copyWith({
    SidePanelType? openPanel,
    bool? isPinned,
    double? width,
    String? panelData,
    bool? autoFocus,
    bool clearPanel = false,
    bool clearData = false,
  }) {
    return SidePanelState(
      openPanel: clearPanel ? null : (openPanel ?? this.openPanel),
      isPinned: isPinned ?? this.isPinned,
      width: width ?? this.width,
      panelData: clearData ? null : (panelData ?? this.panelData),
      autoFocus: autoFocus ?? this.autoFocus,
    );
  }
}

/// Complete state for both sidebar slots.
class SidePanelsState {
  final SidePanelState left;
  final SidePanelState right;

  const SidePanelsState({
    this.left = const SidePanelState(),
    this.right = const SidePanelState(),
  });

  /// True when the dictionary panel is open (in either slot).
  bool get isDictionaryOpen =>
      left.openPanel == SidePanelType.dictionary ||
      right.openPanel == SidePanelType.dictionary;

  bool get isAnyOpen => left.openPanel != null || right.openPanel != null;

  /// True when the left sidebar has visible content AND is not collapsed.
  bool get isLeftExpanded => left.openPanel != null;

  /// True when the right sidebar has visible content AND is not collapsed.
  bool get isRightExpanded => right.openPanel != null;
}

/// Notifier for managing sidebar panel states.
class SidePanelNotifier extends StateNotifier<SidePanelsState> {
  SidePanelNotifier() : super(const SidePanelsState());

  /// Toggle a panel. If already open in the same slot, close it.
  /// If another panel is open in the same slot, replace it.
  void toggle(SidePanelType panel, {String? data, bool autoFocus = false}) {
    final slot = _slotFor(panel);
    final current = slot == PanelSlot.left ? state.left : state.right;

    if (current.openPanel == panel) {
      // Toggle off
      _closeSlot(slot);
    } else {
      // Open (and close previous in same slot)
      _openInSlot(panel, slot, data: data, autoFocus: autoFocus);
    }
  }

  /// Open a panel in its appropriate slot.
  void open(
    SidePanelType panel, {
    String? data,
    bool? pin,
    bool autoFocus = false,
  }) {
    final slot = _slotFor(panel);
    _openInSlot(panel, slot, data: data, autoFocus: autoFocus);

    if (pin == true) {
      _setPinned(slot, true);
    }
  }

  /// Close a specific panel. If no panel specified, close all.
  void close([SidePanelType? panel]) {
    if (panel == null) {
      state = const SidePanelsState();
      return;
    }
    final slot = _slotFor(panel);
    _closeSlot(slot);
  }

  /// Close all panels.
  void closeAll() {
    state = const SidePanelsState();
  }

  /// Toggle pin state for a panel.
  void togglePin(SidePanelType? panel) {
    if (panel == null) return;
    final slot = _slotFor(panel);
    final current = slot == PanelSlot.left ? state.left : state.right;
    _setPinned(slot, !current.isPinned);
  }

  /// Set the data payload for an open panel (e.g. dictionary word).
  void setPanelData(SidePanelType panel, String data) {
    final slot = _slotFor(panel);
    final current = slot == PanelSlot.left ? state.left : state.right;
    if (current.openPanel == panel) {
      _updateSlot(slot, panelData: data);
    }
  }

  /// Update panel data (for dictionary word changes without toggling).
  void updateDictionaryWord(String word) {
    final right = state.right;
    if (right.openPanel == SidePanelType.dictionary) {
      state = SidePanelsState(
        left: state.left,
        right: right.copyWith(panelData: word),
      );
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────

  PanelSlot _slotFor(SidePanelType panel) {
    switch (panel) {
      case SidePanelType.dictionary:
        return PanelSlot.right;
      case SidePanelType.library:
      case SidePanelType.gavesana:
        return PanelSlot.left;
      case SidePanelType.contents:
        return PanelSlot.left;
      case SidePanelType.search:
        return PanelSlot.left;
    }
  }

  void _openInSlot(
    SidePanelType panel,
    PanelSlot slot, {
    String? data,
    bool autoFocus = false,
  }) {
    final newState = SidePanelState(
      openPanel: panel,
      isPinned: false,
      panelData: data,
      autoFocus: autoFocus,
    );
    _updateSlotState(slot, newState);
  }

  void _closeSlot(PanelSlot slot) {
    _updateSlotState(slot, const SidePanelState());
  }

  void _setPinned(PanelSlot slot, bool pinned) {
    _updateSlot(slot, isPinned: pinned);
  }

  void _updateSlot(
    PanelSlot slot, {
    SidePanelType? openPanel,
    bool? isPinned,
    double? width,
    String? panelData,
    bool? autoFocus,
    bool clearPanel = false,
    bool clearData = false,
  }) {
    final current = slot == PanelSlot.left ? state.left : state.right;
    final updated = current.copyWith(
      openPanel: openPanel,
      isPinned: isPinned,
      width: width,
      panelData: panelData,
      autoFocus: autoFocus,
      clearPanel: clearPanel,
      clearData: clearData,
    );
    _updateSlotState(slot, updated);
  }

  void _updateSlotState(PanelSlot slot, SidePanelState updated) {
    state = SidePanelsState(
      left: slot == PanelSlot.left ? updated : state.left,
      right: slot == PanelSlot.right ? updated : state.right,
    );
  }
}

/// Provider for the sidebar panel state.
final sidePanelProvider =
    StateNotifierProvider<SidePanelNotifier, SidePanelsState>((ref) {
      return SidePanelNotifier();
    });

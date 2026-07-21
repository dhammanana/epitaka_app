// lib/features/reader/widgets/reader_selection_overlay.dart
//
// Custom text-selection overlay for the reader. Replaces the framework
// [SelectionArea], which crashes on lazily-scrolled/recycled paragraph lists
// (flutter/flutter#124078, #152420).
//
// We select a single paragraph (chosen by long-press in the reader screen)
// and paint a highlight over its render box. The highlight is recomputed
// from the live render object so it stays correct while the list scrolls or
// the tab is switched — without holding onto stale render objects.
// A small toolbar above the selection offers the copy-with-style actions.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../shared/utils/copy_types.dart';
import 'reader_context_menu.dart' show ContextMenuButton;
import '../providers/reader_provider.dart';
import 'dart:developer' as developer;

class ReaderSelectionOverlay extends StatefulWidget {
  final int? selectedParagraphIndex;

  /// paraId of the selected paragraph, or null when nothing is selected.
  /// Used only to decide whether to render; the actual box is located via
  /// [findRenderBox] (which walks the reader list's render tree) so we never
  /// re-key a list item at runtime (that re-parent crashes semantics — see
  /// reader_screen.dart [_selectedParagraphIndex]).
  final int? selectedParagraphParaId;

  /// Locates the [RenderBox] of the selected paragraph. Supplied by the
  /// reader screen; returns null if the paragraph is scrolled out / not built.
  final RenderBox? Function() findRenderBox;
  final List<ParagraphData> paragraphs;
  final Color highlightColor;
  final void Function(CopyScope scope, bool addQuote) onCopy;
  final VoidCallback onClear;

  const ReaderSelectionOverlay({
    super.key,
    required this.selectedParagraphIndex,
    required this.selectedParagraphParaId,
    required this.findRenderBox,
    required this.paragraphs,
    required this.highlightColor,
    required this.onCopy,
    required this.onClear,
  });

  @override
  State<ReaderSelectionOverlay> createState() => _ReaderSelectionOverlayState();
}

class _ReaderSelectionOverlayState extends State<ReaderSelectionOverlay>
    with SingleTickerProviderStateMixin {
  // Drives a per-frame rect recompute while a paragraph is selected so the
  // highlight tracks scrolling. We do NOT call setState() from the ticker:
  // rebuilding the (interactive Material) toolbar subtree every frame churns
  // the semantics tree during flushSemantics and forces layout mid-build,
  // which leaves parent data dirty and triggers the framework's
  // '!semantics.parentDataDirty' / '!conflict' assertions. Instead we push the
  // computed rect into [_highlightRect]; only the cheap CustomPaint (and a
  // lightweight Positioned wrapper) rebuild, and only when the rect changes.
  late final Ticker _ticker;

  /// Live, local-space rect of the selected paragraph, or null when hidden.
  final ValueNotifier<Rect?> _highlightRect = ValueNotifier<Rect?>(null);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant ReaderSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTicker();
  }

  void _updateTicker() {
    if (widget.selectedParagraphIndex != null) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
      // Clear the rect when there is nothing selected so the highlight and
      // toolbar disappear immediately (build() also guards this).
      _highlightRect.value = null;
    }
  }

  void _onTick(Duration _) => _updateRect();

  /// Recomputes the selected paragraph's rect in this overlay's local space.
  /// Runs from the ticker (scheduler phase, after the previous frame's layout
  /// is current) so it never forces layout during build.
  void _updateRect() {
    if (!mounted) return;

    final selectedCtx = widget.findRenderBox();
    developer.log(
      '[DBG] _updateRect: tick paraId=${widget.selectedParagraphParaId} '
      'box=${selectedCtx == null ? 'null' : 'found(attached=${selectedCtx.attached})'}',
      name: 'epitaka.dict',
    );
    if (selectedCtx == null) {
      _highlightRect.value = null;
      return;
    }
    final box = selectedCtx;
    if (!box.attached) {
      _highlightRect.value = null;
      return;
    }

    final globalRect = box.localToGlobal(Offset.zero) & box.size;
    final overlayBox = context.findRenderObject();
    if (overlayBox is RenderBox) {
      final topLeft = overlayBox.globalToLocal(globalRect.topLeft);
      final newRect = topLeft & globalRect.size;
      if (_highlightRect.value != newRect) _highlightRect.value = newRect;
    } else {
      _highlightRect.value = null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _highlightRect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.selectedParagraphIndex;
    if (index == null ||
        widget.selectedParagraphParaId == null ||
        index < 0 ||
        index >= widget.paragraphs.length) {
      // Ensure the highlight/toolbar are hidden when nothing is selected.
      if (_highlightRect.value != null) _highlightRect.value = null;
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;

    // Built once per selection (not per frame): the toolbar is an interactive
    // Material subtree, so we keep it as a stable instance and only move it
    // via the Positioned wrapper below.
    final toolbar = ReaderSelectionToolbar(
      colors: colors,
      onCopy: widget.onCopy,
      onClear: widget.onClear,
    );

    return Stack(
      children: [
        IgnorePointer(
          ignoring: true,
          child: AnimatedBuilder(
            animation: _highlightRect,
            builder: (context, _) => CustomPaint(
              painter: _SelectionHighlightPainter(
                localRect: _highlightRect.value,
                color: widget.highlightColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _highlightRect,
          builder: (context, child) {
            final rect = _highlightRect.value;
            if (rect == null) return const SizedBox.shrink();
            // Position the toolbar just above the highlight (clamped into view).
            const toolbarHeight = 44.0;
            final dy = (rect.top - toolbarHeight - 8).clamp(
              8.0,
              double.infinity,
            );
            return Positioned(left: rect.left, top: dy, child: child!);
          },
          child: toolbar,
        ),
      ],
    );
  }
}

class _SelectionHighlightPainter extends CustomPainter {
  final Rect? localRect;
  final Color color;

  _SelectionHighlightPainter({this.localRect, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (localRect == null) return;
    final paint = Paint()..color = color;
    final rrect = RRect.fromRectAndRadius(
      localRect!.deflate(2),
      const Radius.circular(6),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _SelectionHighlightPainter old) =>
      old.localRect != localRect || old.color != color;
}

/// A small floating toolbar shown above a selected paragraph, offering the
/// copy-with-style actions.
class ReaderSelectionToolbar extends StatelessWidget {
  final ColorScheme colors;
  final void Function(CopyScope scope, bool addQuote) onCopy;
  final VoidCallback onClear;

  const ReaderSelectionToolbar({
    super.key,
    required this.colors,
    required this.onCopy,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContextMenuButton(
              icon: Icons.copy_all,
              label: 'Copy with Style',
              onTap: () => onCopy(CopyScope.both, false),
              colors: colors,
            ),
            ContextMenuButton(
              icon: Icons.text_fields,
              label: 'Pāli Only',
              onTap: () => onCopy(CopyScope.pali, false),
              colors: colors,
            ),
            ContextMenuButton(
              icon: Icons.translate,
              label: 'Translation Only',
              onTap: () => onCopy(CopyScope.translation, false),
              colors: colors,
            ),
            ContextMenuButton(
              icon: Icons.format_quote,
              label: 'Copy with Quote',
              onTap: () => onCopy(CopyScope.both, true),
              colors: colors,
            ),
            ContextMenuButton(
              icon: Icons.close,
              label: 'Clear',
              onTap: onClear,
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }
}

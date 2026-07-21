import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// A [ScrollController] implementation that bridges to a
/// [ScrollablePositionedList]'s internal scroll controller via
/// [ScrollOffsetController].
///
/// This enables the [Selectable] package's autoscroll feature to work with
/// [ScrollablePositionedList] by delegating scroll animations to the
/// list's internal [ScrollOffsetController].
class PositionedListScrollController extends ScrollController {
  /// The [ScrollOffsetController] from the [ScrollablePositionedList].
  final ScrollOffsetController? scrollOffsetController;

  /// The current scroll position, kept in sync via [ScrollNotification]s.
  double _currentOffset = 0.0;

  /// Whether we're currently performing a programmatic scroll (to avoid
  /// feedback loops).
  bool _isProgrammaticScroll = false;

  PositionedListScrollController({
    this.scrollOffsetController,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    _currentOffset = position.pixels;
    // Listen to scroll notifications to keep our offset in sync
    position.addListener(_onPositionChange);
  }

  @override
  void detach(ScrollPosition position) {
    position.removeListener(_onPositionChange);
    super.detach(position);
  }

  void _onPositionChange() {
    if (!_isProgrammaticScroll) {
      _currentOffset = position.pixels;
      notifyListeners();
    }
  }

  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) async {
    if (scrollOffsetController == null) {
      // Fallback: use the attached position directly if available
      if (hasClients) {
        await position.animateTo(offset, duration: duration, curve: curve);
      }
      return;
    }

    _isProgrammaticScroll = true;
    final currentOffset = _currentOffset;
    final delta = offset - currentOffset;

    if (delta.abs() > 0.1) {
      await scrollOffsetController!.animateScroll(
        offset: delta,
        duration: duration,
        curve: curve,
      );
    }

    _isProgrammaticScroll = false;
    // The scroll notification will update _currentOffset via _onPositionChange
  }

  @override
  void jumpTo(double offset) {
    if (scrollOffsetController == null) {
      if (hasClients) {
        position.jumpTo(offset);
      }
      return;
    }

    _isProgrammaticScroll = true;
    final currentOffset = _currentOffset;
    final delta = offset - currentOffset;

    if (delta.abs() > 0.1) {
      // Jump immediately by animating with zero duration
      scrollOffsetController!.animateScroll(
        offset: delta,
        duration: Duration.zero,
        curve: Curves.linear,
      );
    }

    _isProgrammaticScroll = false;
    _currentOffset = offset;
    notifyListeners();
  }

  /// Updates the [scrollOffsetController] reference (useful when the
  /// [ScrollablePositionedList] is recreated).
  void updateScrollOffsetController(ScrollOffsetController? controller) {
    // Note: we can't easily replace the controller on an existing
    // ScrollController, so this is mainly for reference.
  }

  @override
  String toString() {
    return '${describeIdentity(this)} ($_currentOffset)';
  }
}

import 'package:flutter/material.dart';

import 'gavesana_search_view.dart';

/// Gavesana (AI-powered search) embedded directly in the desktop sidebar.
///
/// Shows the actual search bar + live AI search states (idle hint,
/// running log, error, results) right in the panel — no gateway button
/// that opens a separate window. The full-screen [GavesanaScreen] on
/// mobile uses the same [GavesanaSearchView] widget, so both layouts
/// share one implementation.
class GavesanaPanel extends StatelessWidget {
  /// When true, the query field is focused once the panel is built
  /// (used by keyboard shortcuts so the user can type immediately).
  final bool autoFocus;

  const GavesanaPanel({super.key, this.autoFocus = false});

  @override
  Widget build(BuildContext context) {
    return GavesanaSearchView(autoFocus: autoFocus, dense: true);
  }
}

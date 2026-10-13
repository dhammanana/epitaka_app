import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import '../providers/dpd_settings_provider.dart';
import 'entry_content.dart';
import 'grammar_table.dart';

/// Manages section open/close state and builds the button row and section
/// content of one entry. Grammar and examples only: the other sections come
/// with the Vitthāra level.
mixin EntrySectionsMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final Set<String> openSections = {};

  bool isOpen(String id) => openSections.contains(id);

  void initSectionState() {
    final settings = ref.read(dpdSettingsProvider);
    if (settings.grammarOpen) openSections.add('grammar');
    if (settings.examplesOpen) openSections.add('examples');
  }

  void handleSettingsChange(DpdSettings? prev, DpdSettings next) {
    var changed = false;
    if (prev?.grammarOpen != next.grammarOpen) {
      next.grammarOpen
          ? openSections.add('grammar')
          : openSections.remove('grammar');
      changed = true;
    }
    if (prev?.examplesOpen != next.examplesOpen) {
      next.examplesOpen
          ? openSections.add('examples')
          : openSections.remove('examples');
      changed = true;
    }
    if (changed) setState(() {});
  }

  void toggleSection(String id) {
    setState(() {
      if (!openSections.contains(id)) {
        if (ref.read(dpdSettingsProvider).oneButtonAtATime) {
          openSections.clear();
        }
        openSections.add(id);
      } else {
        openSections.remove(id);
      }
    });
  }

  List<Widget> buildSectionButtons(DpdHeadwordWithRoot h) {
    return [
      if (h.needsGrammarButton)
        DpdSectionButton(
          label: 'grammar',
          isActive: isOpen('grammar'),
          onTap: () => toggleSection('grammar'),
        ),
      if (h.needsExampleButton || h.needsExamplesButton)
        DpdSectionButton(
          label: h.needsExamplesButton ? 'examples' : 'example',
          isActive: isOpen('examples'),
          onTap: () => toggleSection('examples'),
        ),
    ];
  }

  List<Widget> buildSections(DpdHeadwordWithRoot h) {
    return [
      if (isOpen('grammar') && h.needsGrammarButton) GrammarTable(headword: h),
      if (isOpen('examples') && (h.needsExampleButton || h.needsExamplesButton))
        EntryExampleBlock(headword: h),
    ];
  }
}

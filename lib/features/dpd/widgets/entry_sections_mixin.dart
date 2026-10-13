import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import '../database/sutta_info_extensions.dart';
import '../models/frequency_data.dart';
import '../providers/dpd_database_provider.dart';
import '../providers/dpd_settings_provider.dart';
import '../providers/internet_provider.dart';
import '../providers/template_cache_provider.dart';
import '../utils/text_filters.dart';
import 'entry_content.dart';
import 'family_state_mixin.dart';
import 'feedback_section.dart';
import 'frequency_section.dart';
import 'grammar_table.dart';
import 'inflection_section.dart';
import 'sutta_info_section.dart';

/// Manages section open/close state and builds the button row and section
/// content of one entry. Grammar and examples show at every level; the other
/// sections show only at Vitthāra.
///
/// Must be used alongside [FamilyStateMixin]: family reset is coordinated via
/// [onBeforeOpenFamilySection].
mixin EntrySectionsMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, FamilyStateMixin<T> {
  DictionaryLevel get sectionLevel;

  /// The word the user typed, to mark in the inflection table.
  String get sectionLookupKey;

  final Set<String> openSections = {};
  SuttaInfoData? _suttaInfo;
  bool _suttaLoaded = false;
  FrequencyData? _cachedFrequencyData;

  FrequencyData? frequencyData(DpdHeadwordWithRoot h) =>
      _cachedFrequencyData ??= parseFrequencyData(h.freqData);

  bool get _full => sectionLevel == DictionaryLevel.vitthara;

  bool isOpen(String id) => openSections.contains(id);

  void initSectionState() {
    final settings = ref.read(dpdSettingsProvider);
    if (settings.grammarOpen) openSections.add('grammar');
    if (settings.examplesOpen) openSections.add('examples');
    if (_full) _loadSuttaInfo();
  }

  /// Call when the level changes under a card that is kept: the sutta row is
  /// read only at Vitthāra, the one level that shows it.
  void handleLevelChange() {
    if (_full && !_suttaLoaded) _loadSuttaInfo();
  }

  Future<void> _loadSuttaInfo() async {
    final dao = await ref.read(dpdDaoProvider.future);
    final info = await dao.getSuttaInfo(familyHeadword.headword.lemma1);
    if (mounted) {
      setState(() {
        _suttaInfo = info;
        _suttaLoaded = true;
      });
    }
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

  @override
  void onBeforeOpenFamilySection() {
    if (ref.read(dpdSettingsProvider).oneButtonAtATime) {
      setState(() {
        openSections.clear();
        familyResetAll();
      });
    }
  }

  void toggleSection(String id) {
    setState(() {
      if (!openSections.contains(id)) {
        if (ref.read(dpdSettingsProvider).oneButtonAtATime) {
          openSections.clear();
          familyResetAll();
        }
        openSections.add(id);
      } else {
        openSections.remove(id);
      }
    });
  }

  List<Widget> buildSectionButtons(DpdHeadwordWithRoot h) {
    final hasInternet = _full
        ? ref.watch(hasInternetProvider).valueOrNull ?? true
        : false;
    final sutta = _suttaInfo;
    return [
      if (hasInternet)
        // The voice setting arrives with the other DPD options in Phase 4.
        DpdPlayButton(lemma: h.lemma1, gender: 'male'),
      if (_full && _suttaLoaded && sutta != null)
        DpdSectionButton(
          label: sutta.isSamyutta
              ? context.nigg('saṃyutta')
              : sutta.isVagga
              ? 'vagga'
              : sutta.isNipata
              ? 'nipāta'
              : 'sutta',
          isActive: isOpen('sutta'),
          onTap: () => toggleSection('sutta'),
        ),
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
      if (_full && h.needsInflectionButton)
        DpdSectionButton(
          label: h.inflectionButtonLabel,
          isActive: isOpen('inflections'),
          onTap: () => toggleSection('inflections'),
        ),
      if (_full) ...buildFamilyButtons(),
      if (_full && h.needsFrequencyButton)
        DpdSectionButton(
          label: 'frequency',
          isActive: isOpen('frequency'),
          onTap: () => toggleSection('frequency'),
        ),
      if (_full)
        DpdSectionButton(
          label: 'feedback',
          isActive: isOpen('feedback'),
          onTap: () => toggleSection('feedback'),
        ),
    ];
  }

  List<Widget> buildSections(DpdHeadwordWithRoot h) {
    final templateCache = _full
        ? ref.watch(templateCacheProvider).valueOrNull ??
              <String, InflectionTemplate>{}
        : <String, InflectionTemplate>{};
    final sutta = _suttaInfo;
    return [
      if (_full && isOpen('sutta') && sutta != null)
        SuttaInfoSection(
          suttaInfo: sutta,
          headwordId: h.id,
          lemma1: h.lemma1,
        ),
      if (isOpen('grammar') && h.needsGrammarButton)
        GrammarTable(headword: h, audio: _full),
      if (isOpen('examples') && (h.needsExampleButton || h.needsExamplesButton))
        EntryExampleBlock(headword: h),
      if (_full && isOpen('inflections') && h.needsInflectionButton)
        InflectionSection(
          headword: h,
          templateCache: templateCache,
          lookupKey: sectionLookupKey,
        ),
      if (_full) ...buildFamilySections(),
      if (_full && isOpen('frequency') && h.needsFrequencyButton)
        FrequencySection(
          data: frequencyData(h)!,
          headwordId: h.id,
          lemma1: h.lemma1,
        ),
      if (_full && isOpen('feedback'))
        FeedbackSection(headwordId: h.id, lemma1: h.lemma1),
    ];
  }
}

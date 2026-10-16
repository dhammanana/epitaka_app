import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import '../models/family_data.dart';
import '../providers/dpd_database_provider.dart';
import '../providers/family_provider.dart';
import 'entry_content.dart';
import 'family_section_builders.dart';
import 'family_table.dart';
import 'multi_family_section.dart';

mixin FamilyStateMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  DpdHeadwordWithRoot get familyHeadword;

  bool _showRootFamily = false;
  bool _showWordFamily = false;
  bool _showCompoundFamilies = false;
  bool _showIdioms = false;
  bool _showSets = false;

  FamilyRootData? _rootFamilyData;
  FamilyWordData? _wordFamilyData;
  List<FamilyCompoundData>? _compoundData;
  List<FamilyIdiomData>? _idiomData;
  List<FamilySetData>? _setsData;

  DpdHeadwordWithRoot get _fh => familyHeadword;

  String get _lemmaClean => _fh.headword.lemmaClean;

  List<String> get _idiomKeyList {
    final keys = (_fh.familyIdioms ?? '').split(' ').where((s) => s.isNotEmpty).toList();
    return keys.isNotEmpty ? keys : [_lemmaClean];
  }

  bool get familyHasRoot => _fh.needsRootFamilyButton;

  bool get familyHasWord => _fh.needsWordFamilyButton;

  bool get familyHasCompound {
    final cfSet = ref.watch(compoundFamilyKeysProvider).valueOrNull;
    return _fh.needsCompoundFamilyButton(cfSet);
  }

  bool get familyHasIdioms {
    final idiomSet = ref.watch(idiomKeysProvider).valueOrNull;
    return _fh.needsIdiomButton(idiomSet);
  }

  bool get familyHasSets => _fh.needsSetButton;

  bool get familyHasAny =>
      familyHasRoot ||
      familyHasWord ||
      familyHasCompound ||
      familyHasIdioms ||
      familyHasSets;

  Future<void> _loadRootFamily() async {
    if (_rootFamilyData != null) return;
    final dao = await ref.read(dpdDaoProvider.future);
    final data = await dao.getRootFamily(_fh.rootKey!, _fh.familyRoot!);
    if (mounted) setState(() => _rootFamilyData = data);
  }

  Future<void> _loadWordFamily() async {
    if (_wordFamilyData != null) return;
    final dao = await ref.read(dpdDaoProvider.future);
    final data = await dao.getWordFamily(_fh.familyWord!);
    if (mounted) setState(() => _wordFamilyData = data);
  }

  Future<void> _loadCompoundFamilies() async {
    if (_compoundData != null) return;

    final cfSet = ref.read(compoundFamilyKeysProvider).valueOrNull;
    final lemmaInCfSet = cfSet?.contains(_lemmaClean) ?? false;

    final compoundKeys = (_fh.familyCompound ?? '').split(' ').where((s) => s.isNotEmpty).toList();
    List<String> keysToLoad = compoundKeys;
    if (keysToLoad.isEmpty && lemmaInCfSet) {
      keysToLoad = [_lemmaClean];
    }

    if (keysToLoad.isEmpty) {
      if (mounted) setState(() => _compoundData = []);
      return;
    }

    final dao = await ref.read(dpdDaoProvider.future);
    final data = await dao.getCompoundFamilies(keysToLoad);
    if (mounted) setState(() => _compoundData = data);
  }

  Future<void> _loadIdioms() async {
    if (_idiomData != null) return;
    final dao = await ref.read(dpdDaoProvider.future);
    final data = await dao.getIdioms(_idiomKeyList);
    if (mounted) setState(() => _idiomData = data);
  }

  Future<void> _loadSets() async {
    if (_setsData != null) return;
    final dao = await ref.read(dpdDaoProvider.future);
    final data = await dao.getSets(_fh.setKeys);
    if (mounted) setState(() => _setsData = data);
  }

  /// Override in the card state to close all main sections before a family
  /// section opens (for one-button-at-a-time mode).
  void onBeforeOpenFamilySection() {}

  void familyResetAll() {
    _showRootFamily = false;
    _showWordFamily = false;
    _showCompoundFamilies = false;
    _showIdioms = false;
    _showSets = false;
  }

  /// Call when the card is reused for a different headword: hides family
  /// sections and clears cached data so the next toggle loads fresh.
  void familyHandleHeadwordChange() {
    familyResetAll();
    _rootFamilyData = null;
    _wordFamilyData = null;
    _compoundData = null;
    _idiomData = null;
    _setsData = null;
  }

  void familyToggleRoot() {
    if (!_showRootFamily) onBeforeOpenFamilySection();
    setState(() => _showRootFamily = !_showRootFamily);
    if (_showRootFamily) _loadRootFamily();
  }

  void familyToggleWord() {
    if (!_showWordFamily) onBeforeOpenFamilySection();
    setState(() => _showWordFamily = !_showWordFamily);
    if (_showWordFamily) _loadWordFamily();
  }

  void familyToggleCompound() {
    if (!_showCompoundFamilies) onBeforeOpenFamilySection();
    setState(() => _showCompoundFamilies = !_showCompoundFamilies);
    if (_showCompoundFamilies) _loadCompoundFamilies();
  }

  void familyToggleIdioms() {
    if (!_showIdioms) onBeforeOpenFamilySection();
    setState(() => _showIdioms = !_showIdioms);
    if (_showIdioms) _loadIdioms();
  }

  void familyToggleSets() {
    if (!_showSets) onBeforeOpenFamilySection();
    setState(() => _showSets = !_showSets);
    if (_showSets) _loadSets();
  }

  List<Widget> buildFamilyButtons() {
    return [
      if (familyHasRoot)
        DpdSectionButton(
          label: 'root family',
          isActive: _showRootFamily,
          onTap: familyToggleRoot,
        ),
      if (familyHasWord)
        DpdSectionButton(
          label: 'word family',
          isActive: _showWordFamily,
          onTap: familyToggleWord,
        ),
      if (familyHasCompound)
        DpdSectionButton(
          label: _fh.isCompoundFamilyPlural ? 'compound families' : 'compound family',
          isActive: _showCompoundFamilies,
          onTap: familyToggleCompound,
        ),
      if (familyHasIdioms)
        DpdSectionButton(
          label: 'idioms',
          isActive: _showIdioms,
          onTap: familyToggleIdioms,
        ),
      if (familyHasSets)
        DpdSectionButton(
          label: _fh.isSetsPlural ? 'sets' : 'set',
          isActive: _showSets,
          onTap: familyToggleSets,
        ),
    ];
  }

  /// Keyed, so that closing one section does not hand its state to the next:
  /// a compound, idiom and set section share one widget type, and a state
  /// built for fewer sub-families would read past the end of its own list.
  List<Widget> buildFamilySections() {
    return [
      if (_showRootFamily)
        KeyedSubtree(key: const ValueKey('family-root'), child: _buildRootSection()),
      if (_showWordFamily)
        KeyedSubtree(key: const ValueKey('family-word'), child: _buildWordSection()),
      if (_showCompoundFamilies)
        KeyedSubtree(
          key: const ValueKey('family-compound'),
          child: _buildCompoundSection(),
        ),
      if (_showIdioms)
        KeyedSubtree(key: const ValueKey('family-idioms'), child: _buildIdiomsSection()),
      if (_showSets)
        KeyedSubtree(key: const ValueKey('family-sets'), child: _buildSetsSection()),
    ];
  }

  Widget _buildRootSection() {
    final data = _rootFamilyData;
    if (data == null) return const SizedBox.shrink();
    return FamilyTableWidget(
      header: buildRootFamilyHeader(context, data),
      entries: parseFamilyData(data.data),
      footerConfig: buildRootFamilyFooter(_fh.id, _fh.lemma1),
    );
  }

  Widget _buildWordSection() {
    final data = _wordFamilyData;
    if (data == null) return const SizedBox.shrink();
    return FamilyTableWidget(
      header: buildWordFamilyHeader(context, data),
      entries: parseFamilyData(data.data),
      footerConfig: buildWordFamilyFooter(_fh.id, _fh.lemma1),
    );
  }

  Widget _buildCompoundSection() {
    final data = _compoundData;
    if (data == null) return const SizedBox.shrink();
    if (data.isEmpty) return const SizedBox.shrink();
    return MultiFamilySection(
      subSections: data
          .map(
            (row) => FamilySubSection(
              key: row.compoundFamily,
              header: buildCompoundFamilyHeader(context, row),
              entries: parseFamilyData(row.data),
              footerConfig: buildCompoundFamilyFooter(_fh.id, _fh.lemma1),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIdiomsSection() {
    final data = _idiomData;
    if (data == null) return const SizedBox.shrink();
    if (data.isEmpty) {
      return FamilyTableWidget(
        header: const Text('Idioms'),
        entries: const [],
        footerConfig: buildIdiomFooter(_fh.id, _fh.lemma1),
      );
    }
    return MultiFamilySection(
      subSections: data
          .map(
            (row) => FamilySubSection(
              key: row.idiom,
              header: buildIdiomHeader(context, row),
              entries: parseFamilyData(row.data),
              footerConfig: buildIdiomFooter(_fh.id, _fh.lemma1),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSetsSection() {
    final data = _setsData;
    if (data == null) return const SizedBox.shrink();
    if (data.isEmpty) {
      return FamilyTableWidget(
        header: const Text('Sets'),
        entries: const [],
        footerConfig: buildSetFooter(_fh.id, _fh.lemma1),
      );
    }
    return MultiFamilySection(
      subSections: data
          .map(
            (row) => FamilySubSection(
              key: row.set_,
              header: buildSetHeader(context, row, _fh.lemma1),
              entries: parseFamilyData(row.data),
              footerConfig: buildSetFooter(_fh.id, _fh.lemma1),
            ),
          )
          .toList(),
    );
  }
}

import 'dpd_database.dart';

extension DpdHeadwordGrammar on DpdHeadword {
  /// Regex cleanup of lemma_1 (removes numbers at the end)
  String get lemmaClean {
    return lemma1.replaceAll(
      RegExp(r' \d.*$', multiLine: true, unicode: true),
      '',
    );
  }

  /// Regex cleanup of root_key (removes numbers at the end)
  String get rootClean {
    if (rootKey == null) return '';
    return rootKey!.replaceAll(
      RegExp(r' \d.*$', multiLine: true, unicode: true),
      '',
    );
  }

  /// Compile grammar line
  /// Ported from dpd-db meaning_construction.py make_grammar_line
  String get grammarLine {
    String g = grammar ?? '';

    if (neg != null && neg!.isNotEmpty) {
      g += g.isEmpty ? neg! : ', $neg';
    }
    if (verb != null && verb!.isNotEmpty) {
      g += g.isEmpty ? verb! : ', $verb';
    }
    if (trans != null && trans!.isNotEmpty) {
      g += g.isEmpty ? trans! : ', $trans';
    }
    if (plusCase != null && plusCase!.isNotEmpty) {
      g += g.isEmpty ? '($plusCase)' : ' ($plusCase)';
    }

    return g;
  }

  /// Traditional lemma endings map - ported from dpd-db/tools/lemma_traditional.py
  static const Map<String, String> _lemmaTradDict = {
    'ant adj': 'antu',
    'ant masc': 'antu',
    'ar fem': 'u',
    'ar masc': 'u',
    'ar2 masc': 'u',
    'arahant masc': 'arahanta',
    'as masc': 'a',
    'bhavant masc': 'bhavantu',
    'mātar fem': 'mātu',
  };

  /// Traditional lemma - ported from dpd-db/tools/lemma_traditional.py
  String get lemmaTradClean {
    final p = pattern;
    final s = stem;

    // Only process lemmas, not inflected forms (! in stem indicates inflected)
    if (p != null &&
        s != null &&
        !s.contains('!') &&
        _lemmaTradDict.containsKey(p)) {
      final ending = _lemmaTradDict[p]!;
      final trad = '$s$ending'.replaceAll('!', '').replaceAll('*', '');
      return trad;
    }

    return lemmaClean;
  }

  /// Ported from dpd-db tools/meaning_construction.py summarize_construction()
  String get constructionSummary {
    var c = (construction ?? '').replaceAll('<b>', '').replaceAll('</b>', '');

    // if no meaning then show root, word family or nothing
    if ((meaning1 == null || meaning1!.isEmpty) &&
        origin != 'pass1' &&
        origin != 'pass2') {
      if (rootKey != null && rootKey!.isNotEmpty) {
        return (familyRoot ?? '').replaceAll(' ', ' + ');
      } else if (familyWord != null && familyWord!.isNotEmpty) {
        return familyWord!;
      } else {
        return '';
      }
    }

    if ((meaning1 != null && meaning1!.isNotEmpty) ||
        ((meaning1 == null || meaning1!.isEmpty) &&
            (origin == 'pass1' || origin == 'pass2'))) {
      if (construction == null || construction!.isEmpty) return '';

      // remove line2
      c = c.replaceAll(RegExp(r'\n.+$', unicode: true), '');
      // remove phonetic changes
      c = c.replaceAll(RegExp(r'> .[^ ]*? ', unicode: true), '');
      // remove phonetic changes at end
      c = c.replaceAll(RegExp(r' > .[^ ]*?$', unicode: true), '');
      // remove brackets
      c = c.replaceAll('(', '').replaceAll(')', '');
      // remove [insertions]
      c = c.replaceAll(
        RegExp(r'^\[.*\] \+| \[.*\] \+| \+ \[.*\]$', unicode: true),
        '',
      );

      if (rootBase == null || rootBase!.isEmpty) {
        return c.isEmpty ? '' : c;
      }

      // cleanup the base and base_construction
      final baseClean =
          rootBase!.replaceAll(RegExp(r' \(.+\)$', unicode: true), '');
      final base = baseClean.replaceAllMapped(
        RegExp(r'(.+ )(.+?$)', unicode: true),
        (m) => m.group(2)!,
      );
      var baseConstruction = baseClean.replaceAllMapped(
        RegExp(r'(.+)( > .+?$)', unicode: true),
        (m) => m.group(1)!,
      );
      baseConstruction =
          baseConstruction.replaceAll(RegExp(r' >.*', unicode: true), '');

      if (pos != 'fut') {
        final rootSignPlus = (rootSign ?? '').replaceAll(' ', ' + ');
        final rootPlusSign = '$rootClean + $rootSignPlus';
        c = c.replaceAll(base, rootPlusSign);
      } else {
        c = c.replaceAll(base, baseConstruction);
      }
      return c;
    }

    return '';
  }

  /// Ported from dpd-db tools/degree_of_completion.py
  String get degreeOfCompletion {
    if (meaning1 != null && meaning1!.isNotEmpty) {
      if (source1 != null && source1!.isNotEmpty) {
        return '✔';
      } else {
        return '◑';
      }
    } else {
      return '✘';
    }
  }

}

/// Mirrors the webapp's `needs_*` cached_property pattern.
/// Single source of truth for all button/section visibility logic.
extension DpdHeadwordButtons on DpdHeadwordWithRoot {
  static const _conjugationPos = {
    'aor', 'cond', 'fut', 'imp', 'imperf', 'opt', 'perf', 'pr',
  };

  bool get _hasMeaning => meaning1 != null && meaning1!.isNotEmpty;

  // ── Grammar / Examples ────────────────────────────────────────────────────

  bool get needsGrammarButton => _hasMeaning;

  bool get needsExampleButton =>
      _hasMeaning &&
      example1 != null && example1!.isNotEmpty &&
      (example2 == null || example2!.isEmpty);

  bool get needsExamplesButton =>
      _hasMeaning &&
      example1 != null && example1!.isNotEmpty &&
      example2 != null && example2!.isNotEmpty;

  // ── Inflections ───────────────────────────────────────────────────────────

  bool get needsInflectionButton {
    if (stem == '-') return false;
    return stem != null && pattern != null && pattern!.isNotEmpty;
  }

  String get inflectionButtonLabel =>
      _conjugationPos.contains(pos) ? 'conjugation' : 'declension';

  // ── Families ──────────────────────────────────────────────────────────────

  bool get needsRootFamilyButton =>
      familyRoot != null && familyRoot!.isNotEmpty;

  bool get needsWordFamilyButton =>
      familyWord != null && familyWord!.isNotEmpty;

  /// Requires the compound-family key set from [compoundFamilyKeysProvider].
  bool needsCompoundFamilyButton(Set<String>? compoundFamilyKeys) {
    if (!_hasMeaning) return false;
    if (pos?.contains('sandhi') ?? false) return false;
    if (pos?.contains('idiom') ?? false) return false;
    if (compoundType?.contains('?') ?? false) return false;
    final keys = (familyCompound ?? '')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();
    final lemmaInSet =
        compoundFamilyKeys?.contains(headword.lemmaClean) ?? false;
    final keysInSet =
        keys.any((k) => compoundFamilyKeys?.contains(k) ?? false);
    return keysInSet || (lemmaInSet && keys.isEmpty);
  }

  bool get isCompoundFamilyPlural =>
      (familyCompound ?? '').contains(' ');

  /// Requires the idiom key set from [idiomKeysProvider].
  bool needsIdiomButton(Set<String>? idiomKeys) {
    if (!_hasMeaning) return false;
    final idiomKeyList = (familyIdioms ?? '')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();
    final keyList = idiomKeyList.isNotEmpty ? idiomKeyList : [headword.lemmaClean];
    return keyList.any((k) => idiomKeys?.contains(k) ?? false);
  }

  List<String> get setKeys =>
      (familySet ?? '').split('; ').where((s) => s.isNotEmpty).toList();

  bool get needsSetButton => _hasMeaning && setKeys.isNotEmpty;

  bool get isSetsPlural => setKeys.length > 1;

  // ── Frequency ─────────────────────────────────────────────────────────────

  bool get needsFrequencyButton => freqData != null && freqData!.isNotEmpty;
}

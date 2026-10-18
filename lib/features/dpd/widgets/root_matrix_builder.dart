// Map<category, Map<subcategory, List<lemma>>>
typedef RootMatrixData = Map<String, Map<String, List<String>>>;

RootMatrixData buildRootMatrix(
  List<({String lemma1, String pos, String rootBase, String grammar})>
      headwords,
) {
  final data = _emptyMatrix();

  for (final hw in headwords) {
    final lemma = _superscriptNumbers(hw.lemma1);
    final pos = hw.pos;
    final rootBase = hw.rootBase;
    final grammar = hw.grammar;

    if (_verbPos.contains(pos)) {
      final mod = _modifierStandard(rootBase,
          extraDesidCaus: pos == 'pr' || pos == 'abs',
          extraIntensCaus: pos == 'pr');
      data['verbs']!['$pos$mod']?.add(lemma);
    } else if (pos == 'prp') {
      final mod = _modifierPrp(rootBase);
      data['participles']!['prp$mod']?.add(lemma);
    } else if (pos == 'pp') {
      final mod = _modifierStandard(rootBase);
      data['participles']!['pp$mod']?.add(lemma);
    } else if (pos == 'adj' && _hasWord(grammar, 'prp')) {
      final mod = _modifierStandard(rootBase);
      data['participles']!['prp$mod']?.add(lemma);
    } else if (_hasWord(grammar, 'app')) {
      data['participles']!['app']?.add(lemma);
    } else if (pos == 'ptp') {
      final mod = _modifierStandard(rootBase);
      data['participles']!['ptp$mod']?.add(lemma);
    } else if (pos == 'adj' && grammar.contains('ptp')) {
      final mod = _modifierStandard(rootBase);
      data['participles']!['ptp$mod']?.add(lemma);
    } else if (pos == 'masc') {
      final mod = _modifierStandard(rootBase);
      data['nouns']!['masc$mod']?.add(lemma);
    } else if (pos == 'root' && grammar.contains('masc')) {
      final mod = _modifierStandard(rootBase);
      data['nouns']!['masc$mod']?.add(lemma);
    } else if (pos == 'fem') {
      final mod = _modifierStandard(rootBase);
      data['nouns']!['fem$mod']?.add(lemma);
    } else if (pos == 'card' && grammar.contains('fem')) {
      final mod = _modifierStandard(rootBase);
      data['nouns']!['fem$mod']?.add(lemma);
    } else if (pos == 'nt') {
      final mod = _modifierStandard(rootBase);
      data['nouns']!['nt$mod']?.add(lemma);
    } else if (hw.lemma1 == 'sogandhika 3') {
      data['nouns']!['nt']?.add(lemma);
    } else if (pos == 'adj' && _hasWord(grammar, 'pp')) {
      final mod = _modifierStandard(rootBase);
      data['participles']!['pp$mod']?.add(lemma);
    } else if (pos == 'adj') {
      final mod = _modifierStandard(rootBase);
      data['adjectives']!['adj$mod']?.add(lemma);
    } else if (pos == 'suffix' && rootBase.contains('adj')) {
      final mod = _modifierStandard(rootBase);
      data['adjectives']!['adj$mod']?.add(lemma);
    } else if (pos == 'ind') {
      final mod = _modifierStandard(rootBase);
      data['adverbs']!['ind$mod']?.add(lemma);
    } else if (pos == 'suffix') {
      final mod = _modifierStandard(rootBase);
      data['adverbs']!['ind$mod']?.add(lemma);
    }
  }

  return data;
}

const _verbPos = {
  'pr', 'imp', 'opt', 'perf', 'imperf', 'aor', 'fut', 'cond', 'abs', 'ger',
  'inf',
};

bool _hasWord(String text, String word) {
  return RegExp(r'\b' + word + r'\b').hasMatch(text);
}

bool _hasCaus(String s) => _hasWord(s, 'caus');
bool _hasPass(String s) => _hasWord(s, 'pass');
bool _hasDesid(String s) => _hasWord(s, 'desid');
bool _hasIntens(String s) => _hasWord(s, 'intens');
bool _hasDeno(String s) => _hasWord(s, 'deno');

String _modifierStandard(
  String rootBase, {
  bool extraDesidCaus = false,
  bool extraIntensCaus = false,
}) {
  if (_hasCaus(rootBase) && _hasPass(rootBase)) return ' caus & pass';
  if (extraDesidCaus && _hasDesid(rootBase) && _hasCaus(rootBase)) {
    return ' desid & caus';
  }
  if (extraIntensCaus && _hasIntens(rootBase) && _hasCaus(rootBase)) {
    return ' intens & caus';
  }
  if (_hasDeno(rootBase) && _hasCaus(rootBase)) return ' deno & caus';
  if (_hasCaus(rootBase)) return ' caus';
  if (_hasPass(rootBase)) return ' pass';
  if (_hasIntens(rootBase)) return ' intens';
  if (_hasDesid(rootBase)) return ' desid';
  if (_hasDeno(rootBase)) return ' deno';
  return '';
}

String _modifierPrp(String rootBase) {
  if (_hasCaus(rootBase) && _hasPass(rootBase)) return ' caus & pass';
  if (_hasDesid(rootBase) && _hasPass(rootBase)) return ' desid & pass';
  if (_hasDeno(rootBase) && _hasCaus(rootBase)) return ' deno & caus';
  if (_hasCaus(rootBase)) return ' caus';
  if (_hasPass(rootBase)) return ' pass';
  if (_hasIntens(rootBase)) return ' intens';
  if (_hasDesid(rootBase)) return ' desid';
  if (_hasDeno(rootBase)) return ' deno';
  return '';
}

String _superscriptNumbers(String lemma) {
  const digits = {
    0x30: '⁰', 0x31: '¹', 0x32: '²', 0x33: '³', 0x34: '⁴',
    0x35: '⁵', 0x36: '⁶', 0x37: '⁷', 0x38: '⁸', 0x39: '⁹',
  };
  final buf = StringBuffer();
  for (final rune in lemma.runes) {
    final sup = digits[rune];
    if (sup != null) {
      buf.write(sup);
    } else {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

RootMatrixData _emptyMatrix() => {
      'verbs': {
        for (final pos in [
          'pr', 'imp', 'opt', 'perf', 'imperf', 'aor', 'fut', 'cond', 'abs',
          'ger', 'inf',
        ])
          for (final mod in [
            '', ' caus', ' caus & pass', ' pass', ' desid', ' desid & caus',
            ' intens', ' intens & caus', ' deno', ' deno & caus',
          ])
            '$pos$mod': <String>[],
      },
      'participles': {
        for (final pos in ['prp', 'pp', 'ptp'])
          for (final mod in [
            '', ' caus', ' caus & pass', ' pass', ' desid', ' desid & caus',
            ' intens', ' deno', ' deno & caus',
          ])
            '$pos$mod': <String>[],
        'prp desid & pass': <String>[],
        'app': <String>[],
      },
      'nouns': {
        for (final pos in ['masc', 'fem', 'nt'])
          for (final mod in [
            '', ' caus', ' caus & pass', ' pass', ' desid', ' desid & caus',
            ' intens', ' deno', ' deno & caus',
          ])
            '$pos$mod': <String>[],
      },
      'adjectives': {
        for (final mod in [
          '', ' caus', ' caus & pass', ' pass', ' desid', ' desid & caus',
          ' intens', ' deno', ' deno & caus',
        ])
          'adj$mod': <String>[],
      },
      'adverbs': {
        for (final mod in [
          '', ' caus', ' caus & pass', ' pass', ' desid', ' desid & caus',
          ' intens', ' deno', ' deno & caus',
        ])
          'ind$mod': <String>[],
      },
    };

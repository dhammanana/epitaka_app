/// Hangul (Korean) transliteration of Pāli.
///
/// The rules follow the Korean edition of the Tipiṭaka glossary
/// (니까야 번역 용어집 v1.1, §1.1–1.5, confirmed 2026-09-25):
///
///  * tenuis stops use the tense jamo so the Hangul reads close to the Pāli
///    pronunciation: k → ㄲ, c → ㅉ, ṭ/t → ㄸ, p → ㅃ;
///  * aspirated stops use the aspirated jamo: kh → ㅋ, ch → ㅊ, ṭh/th → ㅌ,
///    ph → ㅍ;
///  * voiced and voiced-aspirated stops fall together on the plain jamo:
///    g/gh → ㄱ, j/jh → ㅈ, ḍ/ḍh → ㄷ, d/dh → ㄷ, b/bh → ㅂ;
///  * ṅ/ṃ → ㅇ, ñ/ṇ/n → ㄴ, m → ㅁ, s → ㅅ, h → ㅎ, r/l/ḷ → ㄹ;
///  * ñ before a/e/o carries a y-glide (냐·녜·뇨), y → 야·유·예·요,
///    v → 와·위·우·웨·오;
///  * vowel length is not written: a/ā ㅏ, i/ī ㅣ, u/ū ㅜ, e ㅔ, o ㅗ
///    (Sāriputta → 사리뿟따, Ānanda → 아난다);
///  * a geminate writes its first consonant as the batchim of the preceding
///    syllable, using only the seven legal finals ㄱ ㄴ ㄹ ㅁ ㅂ ㅅ ㅇ
///    (kk → ㄱ, tt/cc/jj/ss → ㅅ, pp/bb → ㅂ, nn/ṇṇ/ññ → ㄴ, mm → ㅁ,
///    ll/ḷḷ → ㄹ): bhikkhu 빅쿠, sutta 숫따, Dhamma 담마, Puṇṇa 뿐나;
///  * a nasal before another consonant becomes the batchim
///    (Saṅgha 상가, Ānanda 아난다, Bimbisāra 빔비사라);
///  * a single intervocalic l/ḷ adds a ㄹ batchim to the preceding syllable
///    (Kosala 꼬살라, Uruvelā 우루웰라, Aṅgulimāla 앙굴리말라); a single
///    intervocalic r does not (Uruvelā → 우루웰라, not 우룰웰라);
///  * consonant + yā fuses into one syllable (Sakya 사꺄,
///    Māluṅkyaputta 말룽꺄뿟따);
///  * a consonant with no vowel takes 으 (Brahmā 브라흐마).
///
/// Names keep their stem form because the Roman source already does
/// (Ānando is written Ānanda), and names with a fixed translation
/// (Buddha → 부처님, Bhagavā → 세존, Brahmā → 범천) and compound place
/// names (Jetavana → 제따 숲) are handled by the translator, not here.
///
/// The rest of the app pivots every script through Sinhala (see
/// `pali_script_converter.dart`), so this module converts Sinhala ⇄ Hangul;
/// Roman input reaches it through the normal Roman → Sinhala step.
library;

/// Sinhala virama (al / hal).
const String _virama = '\u0DCA';

// Hangul jamo indices used by the syllable composition below.
const Map<String, int> _initialIndex = {
  'ㄱ': 0,
  'ㄲ': 1,
  'ㄴ': 2,
  'ㄷ': 3,
  'ㄸ': 4,
  'ㄹ': 5,
  'ㅁ': 6,
  'ㅂ': 7,
  'ㅃ': 8,
  'ㅅ': 9,
  'ㅆ': 10,
  'ㅇ': 11,
  'ㅈ': 12,
  'ㅉ': 13,
  'ㅊ': 14,
  'ㅋ': 15,
  'ㅌ': 16,
  'ㅍ': 17,
  'ㅎ': 18,
};

const Map<String, int> _medialIndex = {
  'ㅏ': 0,
  'ㅐ': 1,
  'ㅑ': 2,
  'ㅒ': 3,
  'ㅓ': 4,
  'ㅔ': 5,
  'ㅕ': 6,
  'ㅖ': 7,
  'ㅗ': 8,
  'ㅘ': 9,
  'ㅙ': 10,
  'ㅚ': 11,
  'ㅛ': 12,
  'ㅜ': 13,
  'ㅝ': 14,
  'ㅞ': 15,
  'ㅟ': 16,
  'ㅠ': 17,
  'ㅡ': 18,
  'ㅢ': 19,
  'ㅣ': 20,
};

/// Batchim jamo → final index. Only the seven legal finals are used, so
/// every other consonant simply has no batchim entry (`null` here).
const Map<String, int> _finalIndex = {
  '': 0,
  'ㄱ': 1,
  'ㄴ': 4,
  'ㄷ': 7,
  'ㄹ': 8,
  'ㅁ': 16,
  'ㅂ': 17,
  'ㅅ': 19,
  'ㅇ': 21,
};

/// Sinhala consonant → (syllable-initial jamo, batchim jamo).
///
/// The batchim is `null` when the consonant is never written as a final
/// (y, r, v, h): such a half-consonant takes an inserted 으 syllable instead
/// (Brahmā → 브라흐마).
const Map<String, (String, String?)> _consonants = {
  // velar stops
  'ක': ('ㄲ', 'ㄱ'),
  'ඛ': ('ㅋ', 'ㄱ'),
  'ග': ('ㄱ', 'ㄱ'),
  'ඝ': ('ㄱ', 'ㄱ'),
  'ඞ': ('ㅇ', 'ㅇ'),
  // palatal stops
  'ච': ('ㅉ', 'ㅅ'),
  'ඡ': ('ㅊ', 'ㅅ'),
  'ජ': ('ㅈ', 'ㅅ'),
  'ඣ': ('ㅈ', 'ㅅ'),
  'ඤ': ('ㄴ', 'ㄴ'),
  // retroflex stops
  'ට': ('ㄸ', 'ㅅ'),
  'ඨ': ('ㅌ', 'ㅅ'),
  'ඩ': ('ㄷ', 'ㅅ'),
  'ඪ': ('ㄷ', 'ㅅ'),
  'ණ': ('ㄴ', 'ㄴ'),
  // dental stops
  'ත': ('ㄸ', 'ㅅ'),
  'ථ': ('ㅌ', 'ㅅ'),
  'ද': ('ㄷ', 'ㅅ'),
  'ධ': ('ㄷ', 'ㅅ'),
  'න': ('ㄴ', 'ㄴ'),
  // labial stops
  'ප': ('ㅃ', 'ㅂ'),
  'ඵ': ('ㅍ', 'ㅂ'),
  'බ': ('ㅂ', 'ㅂ'),
  'භ': ('ㅂ', 'ㅂ'),
  'ම': ('ㅁ', 'ㅁ'),
  // liquids and fricatives
  'ය': ('ㅇ', null),
  'ර': ('ㄹ', null),
  'ල': ('ㄹ', 'ㄹ'),
  'ළ': ('ㄹ', 'ㄹ'),
  'ව': ('ㅇ', null),
  'ස': ('ㅅ', 'ㅅ'),
  'හ': ('ㅎ', null),
};

/// Dependent vowel signs → medial jamo (`''` is the inherent a).
const Map<String, String> _vowelSigns = {
  '': 'ㅏ',
  'ා': 'ㅏ',
  'ි': 'ㅣ',
  'ී': 'ㅣ',
  'ු': 'ㅜ',
  'ූ': 'ㅜ',
  'ෙ': 'ㅔ',
  'ො': 'ㅗ',
};

/// Independent vowels → medial jamo, written with the silent ㅇ initial.
const Map<String, String> _independentVowels = {
  'අ': 'ㅏ',
  'ආ': 'ㅏ',
  'ඉ': 'ㅣ',
  'ඊ': 'ㅣ',
  'උ': 'ㅜ',
  'ඌ': 'ㅜ',
  'එ': 'ㅔ',
  'ඔ': 'ㅗ',
};

/// y-glide forms (y, and ñ before a/e/o): 야 유 예 요.
const Map<String, String> _yGlide = {
  'ㅏ': 'ㅑ',
  'ㅣ': 'ㅣ',
  'ㅜ': 'ㅠ',
  'ㅔ': 'ㅖ',
  'ㅗ': 'ㅛ',
};

/// v → w-glide forms: 와 위 우 웨 오.
const Map<String, String> _wGlide = {
  'ㅏ': 'ㅘ',
  'ㅣ': 'ㅟ',
  'ㅜ': 'ㅜ',
  'ㅔ': 'ㅞ',
  'ㅗ': 'ㅗ',
};

/// One Hangul syllable, kept mutable so a later half-consonant can still
/// become its batchim.
class _Syllable {
  _Syllable(this.initial, this.medial, {this.batchim, this.inserted = false});

  final String initial;
  final String medial;

  /// Batchim jamo, or `null` when the syllable is open.
  String? batchim;

  /// Whether the syllable was created for a consonant without a vowel
  /// (the inserted 으) and so must not take a batchim from the next cluster.
  final bool inserted;

  String get text {
    final l = _initialIndex[initial]!;
    final v = _medialIndex[medial]!;
    final t = _finalIndex[batchim ?? '']!;
    return String.fromCharCode(0xAC00 + (l * 21 + v) * 28 + t);
  }
}

/// Converts Sinhala-script Pāli to Hangul.
///
/// Non-Pāli characters (spaces, punctuation, digits, Latin text) are copied
/// through unchanged.
String paliKoreanFromSinhala(String text) {
  // The Sinhala pivot carries ZWJ joiners (beautifySinhala adds one before
  // ය/ර); they would hide the virama from the cluster rules below.
  text = text.replaceAll(RegExp('[\u200C\u200D]'), '');

  final out = StringBuffer();
  final word = <_Syllable>[];
  // A consonant whose virama is followed by ය (consonant + yā joins one
  // syllable: Sakya → 사꺄).
  String? pendingOnset;

  void flush() {
    final pending = pendingOnset;
    if (pending != null) {
      word.add(_Syllable(_consonants[pending]!.$1, 'ㅡ', inserted: true));
      pendingOnset = null;
    }
    for (final syllable in word) {
      out.write(syllable.text);
    }
    word.clear();
  }

  var i = 0;
  while (i < text.length) {
    final ch = text[i];

    final independent = _independentVowels[ch];
    if (independent != null) {
      flush();
      word.add(_Syllable('ㅇ', independent));
      i++;
      continue;
    }

    final letter = _consonants[ch];
    if (letter != null) {
      final next = i + 1 < text.length ? text[i + 1] : '';
      final afterVirama = i + 2 < text.length ? text[i + 2] : '';

      if (next == _virama) {
        if (afterVirama == 'ය') {
          pendingOnset = ch;
          i += 2;
          continue;
        }
        _addBatchim(word, letter.$2, letter.$1);
        i += 2;
        continue;
      }

      final sign = _vowelSigns.containsKey(next) ? next : '';
      final base = _vowelSigns[sign]!;
      var medial = base;
      var initial = letter.$1;

      if (ch == 'ය') {
        // yā after a half-consonant fuses into that consonant's syllable.
        if (pendingOnset != null) initial = _consonants[pendingOnset!]!.$1;
        medial = _yGlide[base]!;
        pendingOnset = null;
      } else if (ch == 'ව') {
        medial = _wGlide[base]!;
      } else if (ch == 'ඤ') {
        // ñ carries the y-glide before a/e/o: 냐·녜·뇨.
        medial = _yGlide[base]!;
      }

      // A single intervocalic l/ḷ lengthens the previous syllable with a
      // ㄹ batchim (Kosala → 꼬살라, Uruvelā → 우루웰라).
      if ((ch == 'ල' || ch == 'ළ') &&
          word.isNotEmpty &&
          word.last.batchim == null &&
          !word.last.inserted) {
        word.last.batchim = 'ㄹ';
      }

      word.add(_Syllable(initial, medial));
      i += 1 + sign.length;
      continue;
    }

    if (ch == 'ං') {
      // Niggahīta: ㅇ batchim on the syllable it follows.
      if (word.isNotEmpty && word.last.batchim == null) {
        word.last.batchim = 'ㅇ';
      } else {
        word.add(_Syllable('ㅇ', 'ㅏ', batchim: 'ㅇ'));
      }
      pendingOnset = null;
      i++;
      continue;
    }

    flush();
    out.write(ch);
    i++;
  }
  flush();
  return out.toString();
}

/// Adds a half-consonant ([batchim]) to the last syllable of [word], or
/// writes it as an inserted 으 syllable when it cannot be a batchim.
void _addBatchim(List<_Syllable> word, String? batchim, String initial) {
  if (batchim != null &&
      word.isNotEmpty &&
      word.last.batchim == null &&
      !word.last.inserted) {
    word.last.batchim = batchim;
  } else {
    word.add(_Syllable(initial, 'ㅡ', inserted: true));
  }
}

// ── Hangul → Sinhala ───────────────────────────────────────────────────
// The app needs the reverse direction so that Korean text can feed search,
// the dictionary and the Roman reader. Hangul is lossy for Pāli (ㄹ writes
// both r and l, the ㅅ batchim writes tt/dd/cc/jj/ss alike), so the reverse
// mapping picks the most frequent source: ㄹ → ර, coda ㅅ → ත, coda ㄱ → ක.

const List<String> _backInitial = [
  'ග', 'ක', 'න', 'ද', 'ත', 'ර', 'ම', 'බ', 'ප', 'ස', 'ස', 'ජ', 'ච', 'ඡ', //
  'ඛ', 'ථ', 'ඵ', 'හ',
];

/// Index 11 (ㅇ) has no consonant letter.
const int _ieungIndex = 11;

const Map<int, String> _backVowel = {
  0: '', // ㅏ
  1: '', // ㅐ
  4: '', // ㅓ
  5: 'ෙ', // ㅔ
  8: 'ො', // ㅗ
  13: 'ු', // ㅜ
  18: '්', // ㅡ (the inserted-vowel marker: 브 → බ්)
  19: '', // ㅢ
  20: 'ි', // ㅣ
};

/// y-glide medials → the vowel sign that follows the palatal letter.
const Map<int, String> _backYGlide = {
  2: '', // ㅑ
  3: 'ෙ', // ㅒ
  6: '', // ㅕ
  7: 'ෙ', // ㅖ
  12: 'ො', // ㅛ
  17: 'ු', // ㅠ
};

/// w-glide medials (only ever written with a silent ㅇ initial) → ව + sign.
const Map<int, String> _backWGlide = {
  9: 'ා', // ㅘ
  10: 'ෑ', // ㅙ
  15: 'ෙ', // ㅞ
  16: 'ි', // ㅟ
};

const Map<int, String> _backFinal = {
  1: 'ක්',
  4: 'න්',
  8: 'ල්',
  16: 'ම්',
  17: 'ප්',
  19: 'ත්',
  21: 'ං',
};

/// Converts Hangul Pāli back to Sinhala (opinionated, see the notes above).
///
/// Characters outside the Hangul syllable block are copied through.
String paliKoreanToSinhala(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final offset = rune - 0xAC00;
    if (offset < 0 || offset >= 11172) {
      out.writeCharCode(rune);
      continue;
    }
    final initialIndex = offset ~/ 588;
    final medialIndex = (offset % 588) ~/ 28;
    final finalIndex = offset % 28;

    final initial = initialIndex == _ieungIndex
        ? ''
        : _backInitial[initialIndex - (initialIndex > _ieungIndex ? 1 : 0)];

    final yVowel = _backYGlide[medialIndex];
    final wVowel = _backWGlide[medialIndex];
    final String body;
    if (yVowel != null) {
      if (initial.isEmpty) {
        body = 'ය$yVowel';
      } else if (initial == 'න') {
        body = 'ඤ$yVowel';
      } else {
        body = '$initial්ය$yVowel';
      }
    } else if (wVowel != null) {
      body = initial.isEmpty ? 'ව$wVowel' : '$initial${_backVowel[medialIndex] ?? ''}';
    } else {
      final sign = _backVowel[medialIndex] ?? '';
      // A bare 으 has no consonant to attach the virama to.
      body = initial.isEmpty && sign == '්' ? '' : '$initial$sign';
    }

    out.write(body);
    out.write(_backFinal[finalIndex] ?? '');
  }
  return out.toString();
}

/// The Korean (Hangul) transliteration must follow the Nikāya glossary
/// (니까야 번역 용어집 v1.1 §1.5). Its examples pin down every rule: tense
/// jamo for tenuis stops, ㄱ/ㄴ/ㄹ/ㅁ/ㅂ/ㅅ/ㅇ batchim for geminates and
/// nasal + consonant clusters, intervocalic l/ḷ lengthening, consonant + yā
/// fusion, and 으 insertion for a consonant with no vowel.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:epitaka/core/utils/pali_text_utils.dart';

void main() {
  // Pairs taken from the glossary's §1.5 table and the rules text.
  const examples = <String, String>{
    'sāriputta': '사리뿟따',
    'moggallāna': '목갈라나',
    'ānanda': '아난다',
    'mahākassapa': '마하깟사빠',
    'mahākaccāna': '마하깟짜나',
    'anuruddha': '아누룻다',
    'aññāsikoṇḍañña': '안냐시꼰단냐',
    'rāhula': '라훌라',
    'upāli': '우빨리',
    'devadatta': '데와닷따',
    'vakkali': '왁깔리',
    'vacchagotta': '왓차곳따',
    'kaccānagotta': '깟짜나곳따',
    'anāthapiṇḍika': '아나타삔디까',
    'pasenadi': '빠세나디',
    'ajātasattu': '아자따삿뚜',
    'citta': '찟따',
    'nakulapitā': '나꿀라삐따',
    'khemā': '케마',
    'mahāpajāpatī gotamī': '마하빠자빠띠 고따미',
    'sahampati': '사함빠띠',
    'vaṅgīsa': '왕기사',
    'sāvatthī': '사왓티',
    'rājagaha': '라자가하',
    'vesālī': '웨살리',
    'kosambī': '꼬삼비',
    'bārāṇasī': '바라나시',
    'isipatana': '이시빠따나',
    'kapilavatthu': '까삘라왓투',
    'uruvelā': '우루웰라',
    'nerañjarā': '네란자라',
    'nāḷandā': '날란다',
    'magadha': '마가다',
    'kosala': '꼬살라',
    'veḷuvana': '웰루와나',
    'gijjhakūṭa': '깃자꾸따',
    'jeta': '제따',
    'sakya': '사꺄',
    'koliya': '꼴리야',
    'visākhā': '위사카',
    'uppalavaṇṇā': '웁빨라완나',
    'gotama': '고따마',
    'sakka': '삭까',
    'aṅgulimāla': '앙굴리말라',
    // Rules text (§1.3): geminates, nasal clusters, 으 insertion.
    'bhikkhu': '빅쿠',
    'sutta': '숫따',
    'dhamma': '담마',
    'nibbāna': '닙바나',
    'channa': '찬나',
    'puṇṇa': '뿐나',
    'koṇḍañña': '꼰단냐',
    'mahākoṭṭhita': '마하꼿티따',
    'kassapa': '깟사빠',
    'bimbisāra': '빔비사라',
    'saṅgha': '상가',
    'aṅguttara': '앙굿따라',
    'saṃyutta': '상윳따',
    'brahmā': '브라흐마',
    'māluṅkyaputta': '말룽꺄뿟따',
  };

  group('Roman → Korean (glossary §1.5)', () {
    examples.forEach((roman, korean) {
      test(roman, () {
        expect(convertPaliToScript(roman, Script.korean), korean);
      });
    });
  });

  group('Korean is wired in like every other display script', () {
    test('is offered by the script pickers', () {
      final info = listOfScripts.firstWhere((i) => i.script == Script.korean);
      expect(info.nameInLocale, '한국어');
      expect(Script.korean.englishName, 'Korean');
    });

    test('renders with the bundled NotoSansKR font', () {
      // Bundled so Hangul never falls back to tofu on platforms without a
      // Korean system font.
      expect(scriptFontFamily(Script.korean), 'NotoSansKR');
      expect(paliFontChoices(Script.korean), isEmpty);
    });

    testWidgets('the NotoSansKR font files are bundled assets', (tester) async {
      // Guards the pubspec entry against a renamed or missing file: the
      // family only renders if these assets resolve.
      for (final style in ['Regular', 'Bold']) {
        final data = await rootBundle.load('assets/fonts/NotoSansKR-$style.ttf');
        expect(data.lengthInBytes, greaterThan(1000000));
      }
    });

    test('Hangul text converts back to a Roman headword', () {
      expect(convertToRomanPali('사리뿟따'), 'sariputta');
      // Hangul cannot distinguish d/dh (both ㄷ), so aspiration is lost on
      // the way back — the reverse direction is best effort, not a round trip.
      expect(convertToRomanPali('담마'), 'damma');
    });

    test('mixed Hangul + Roman text keeps both runs', () {
      expect(convertToRomanPali('namo 담마'), 'namo damma');
    });
  });
}

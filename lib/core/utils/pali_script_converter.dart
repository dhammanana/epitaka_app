// Copyright Path Nirvana 2018
// The code and character mapping defined in this file can not be used for any commercial purposes.
// Permission from the auther is required for all other purposes.

// ported to dart by pndaza 2022

// total 18 languages
// scripts are ordered

enum Script {
  sinhala,
  devanagari,
  roman,
  thai,
  laos,
  myanmar,
  khmer,
  bengali,
  gurmukhi,
  taitham,
  gujarati,
  telugu,
  kannada,
  malayalam,
  brahmi,
  tibetan,
  cyrillic,
  tamil,
}

class _CodePointRange {
  final int start;
  final int end;
  const _CodePointRange({required this.start, required this.end});
}

class ScriptInfo {
  final Script script;
  final String nameInLocale;
  final String localeCode;
  final List<_CodePointRange> codePointRanges;
  final int index;
  const ScriptInfo({
    required this.script,
    required this.nameInLocale,
    required this.localeCode,
    required this.codePointRanges,
    required this.index,
  });
}

const List<ScriptInfo> listOfScripts = [
  ScriptInfo(
    script: Script.sinhala,
    nameInLocale: 'සිංහල',
    localeCode: 'si',
    codePointRanges: [_CodePointRange(start: 0x0D80, end: 0x0DFF)],
    index: 0,
  ),
  ScriptInfo(
    script: Script.devanagari,
    nameInLocale: 'हिन्दी',
    localeCode: 'hi',
    codePointRanges: [_CodePointRange(start: 0x0900, end: 0x097F)],
    index: 1,
  ),
  ScriptInfo(
    script: Script.roman,
    nameInLocale: 'Roman',
    localeCode: 'ro',
    codePointRanges: [
      _CodePointRange(start: 0x0000, end: 0x017F),
      _CodePointRange(start: 0x1E00, end: 0x1EFF),
    ],
    index: 3,
  ), // latin extended and latin extended additional blocks
  ScriptInfo(
    script: Script.thai,
    nameInLocale: 'ไทย',
    localeCode: 'th',
    codePointRanges: [
      _CodePointRange(start: 0x0E00, end: 0x0E7F),
      _CodePointRange(start: 0xF700, end: 0xF70F),
    ],
    index: 4,
  ),
  ScriptInfo(
    script: Script.laos,
    nameInLocale: 'ລາວ',
    localeCode: 'lo',
    codePointRanges: [_CodePointRange(start: 0x0E80, end: 0x0EFF)],
    index: 5,
  ),
  ScriptInfo(
    script: Script.myanmar,
    nameInLocale: 'ဗမာစာ',
    localeCode: 'my',
    codePointRanges: [_CodePointRange(start: 0x1000, end: 0x107F)],
    index: 6,
  ),
  ScriptInfo(
    script: Script.khmer,
    nameInLocale: 'ភាសាខ្មែរ',
    localeCode: 'km',
    codePointRanges: [_CodePointRange(start: 0x1780, end: 0x17FF)],
    index: 7,
  ),
  ScriptInfo(
    script: Script.bengali,
    nameInLocale: 'বাংলা',
    localeCode: 'be',
    codePointRanges: [_CodePointRange(start: 0x0980, end: 0x09FF)],
    index: 8,
  ),
  ScriptInfo(
    script: Script.gurmukhi,
    nameInLocale: 'ਗੁਰਮੁਖੀ',
    localeCode: 'gm',
    codePointRanges: [_CodePointRange(start: 0x0A00, end: 0x0A7F)],
    index: 9,
  ),
  ScriptInfo(
    script: Script.taitham,
    nameInLocale: 'Tai Tham LN',
    localeCode: 'tt',
    codePointRanges: [_CodePointRange(start: 0x1A20, end: 0x1AAF)],
    index: 10,
  ),
  ScriptInfo(
    script: Script.gujarati,
    nameInLocale: 'ગુજરાતી',
    localeCode: 'gj',
    codePointRanges: [_CodePointRange(start: 0x0A80, end: 0x0AFF)],
    index: 11,
  ),
  ScriptInfo(
    script: Script.telugu,
    nameInLocale: 'తెలుగు',
    localeCode: 'te',
    codePointRanges: [_CodePointRange(start: 0x0C00, end: 0x0C7F)],
    index: 12,
  ),
  ScriptInfo(
    script: Script.kannada,
    nameInLocale: 'ಕನ್ನಡ',
    localeCode: 'ka',
    codePointRanges: [_CodePointRange(start: 0x0C80, end: 0x0CFF)],
    index: 13,
  ),
  ScriptInfo(
    script: Script.malayalam,
    nameInLocale: 'മലയാളം',
    localeCode: 'mm',
    codePointRanges: [_CodePointRange(start: 0x0D00, end: 0x0D7F)],
    index: 14,
  ),
  ScriptInfo(
    script: Script.brahmi,
    nameInLocale: 'Brāhmī',
    localeCode: 'br',
    //charCodeAt returns two codes for each letter [[0x11000, 0x1107F]]
    codePointRanges: [
      _CodePointRange(start: 0xD804, end: 0xD804),
      _CodePointRange(start: 0xDC00, end: 0xDC7F),
    ],
    index: 15,
  ),
  ScriptInfo(
    script: Script.tibetan,
    nameInLocale: 'བོད་སྐད།',
    localeCode: 'tb',
    codePointRanges: [_CodePointRange(start: 0x0F00, end: 0x0FFF)],
    index: 16,
  ),
  ScriptInfo(
    script: Script.cyrillic,
    nameInLocale: 'кириллица',
    localeCode: 'cy',
    codePointRanges: [
      _CodePointRange(start: 0x0400, end: 0x04FF),
      _CodePointRange(start: 0x0300, end: 0x036F),
    ],
    index: 17,
  ), //charCodeAt returns two codes for each letter [[0x11000, 0x1107F]]
  ScriptInfo(
    script: Script.tamil,
    nameInLocale: 'தமிழ்',
    localeCode: 'ta',
    codePointRanges: [_CodePointRange(start: 0x0B80, end: 0x0BFF)],
    index: 18,
  ),
];

Script? _getScriptForCode(int charCode) {
  for (final script in listOfScripts) {
    final ranges = script.codePointRanges;
    for (final range in ranges) {
      if (charCode >= range.start && charCode <= range.end) {
        return script.script;
      }
    }
  }
  return null;
}

const specials = [
  // independent vowels
  [
    'අ',
    'अ',
    'a',
    'อ',
    'ອ',
    'အ',
    'អ',
    'অ',
    'ਅ',
    '\u1A4B',
    'અ',
    'అ',
    'ಅ',
    'അ',
    '𑀅',
    'ཨ',
    'а',
    'அ',
  ],
  [
    'ආ',
    'आ',
    'ā',
    'อา',
    'ອາ',
    'အာ',
    'អា',
    'আ',
    'ਆ',
    '\u1A4C',
    'આ',
    'ఆ',
    'ಆ',
    'ആ',
    '𑀆',
    'ཨཱ',
    'а̄',
    'ஆ',
  ],
  [
    'ඉ',
    'इ',
    'i',
    'อิ',
    'ອິ',
    'ဣ',
    'ឥ',
    'ই',
    'ਇ',
    '\u1A4D',
    'ઇ',
    'ఇ',
    'ಇ',
    'ഇ',
    '𑀇',
    'ཨི',
    'и',
    'இ',
  ],
  [
    'ඊ',
    'ई',
    'ī',
    'อี',
    'ອີ',
    'ဤ',
    'ឦ',
    'ঈ',
    'ਈ',
    '\u1A4E',
    'ઈ',
    'ఈ',
    'ಈ',
    'ഈ',
    '𑀈',
    'ཨཱི',
    'ӣ',
    'ஈ',
  ],
  [
    'උ',
    'उ',
    'u',
    'อุ',
    'ອຸ',
    'ဥ',
    'ឧ',
    'উ',
    'ਉ',
    '\u1A4F',
    'ઉ',
    'ఉ',
    'ಉ',
    'ഉ',
    '𑀉',
    'ཨུ',
    'у',
    'உ',
  ],
  [
    'ඌ',
    'ऊ',
    'ū',
    'อู',
    'ອູ',
    'ဦ',
    'ឩ',
    'ঊ',
    'ਊ',
    '\u1A50',
    'ઊ',
    'ఊ',
    'ಊ',
    'ഊ',
    '𑀊',
    'ཨཱུ',
    'ӯ',
    'ஊ',
  ],
  [
    'එ',
    'ए',
    'e',
    'อเ',
    'ອເ',
    'ဧ',
    'ឯ',
    'এ',
    'ਏ',
    '\u1A51',
    'એ',
    'ఏ',
    'ಏ',
    'ഏ',
    '𑀏',
    'ཨེ',
    'е',
    'ஏ',
  ],
  [
    'ඔ',
    'ओ',
    'o',
    'อโ',
    'ອໂ',
    'ဩ',
    'ឱ',
    'ও',
    'ਓ',
    '\u1A52',
    'ઓ',
    'ఓ',
    'ಓ',
    'ഓ',
    '𑀑',
    'ཨོ',
    'о',
    'ஓ',
  ],
  // various signs
  [
    'ං',
    'ं',
    'ṃ',
    '\u0E4D',
    '\u0ECD',
    'ံ',
    'ំ',
    'ং',
    'ਂ',
    '\u1A74',
    'ં',
    'ం',
    'ಂ',
    'ം',
    '𑀁',
    '\u0F7E',
    'м̣',
    'ங்',
  ], // niggahita - anusawara
  // visarga - not in pali but deva original text has it (thai/lao/tt - not found. using the closest equivalent per wikipedia)
  [
    'ඃ',
    'ः',
    'ḥ',
    'ะ',
    'ະ',
    'း',
    'ះ',
    'ঃ',
    'ਃ',
    '\u1A61',
    'ઃ',
    'ః',
    'ಃ',
    'ഃ',
    '𑀂',
    '\u0F7F',
    'х̣',
    'ஃ',
  ],
  // virama (al - hal). roman/cyrillic need special handling
  [
    '්',
    '्',
    '',
    '\u0E3A',
    '\u0EBA',
    '္',
    '្',
    '্',
    '੍',
    '\u1A60',
    '્',
    '్',
    '್',
    '്',
    '\uD804\uDC46',
    '\u0F84',
    '',
    '்',
  ],
  // digits
  [
    '0',
    '०',
    '0',
    '๐',
    '໐',
    '၀',
    '០',
    '০',
    '੦',
    '\u1A90',
    '૦',
    '౦',
    '೦',
    '൦',
    '𑁦',
    '༠',
    '0',
    '0',
  ],
  [
    '1',
    '१',
    '1',
    '๑',
    '໑',
    '၁',
    '១',
    '১',
    '੧',
    '\u1A91',
    '૧',
    '౧',
    '೧',
    '൧',
    '𑁧',
    '༡',
    '1',
    '1',
  ],
  [
    '2',
    '२',
    '2',
    '๒',
    '໒',
    '၂',
    '២',
    '২',
    '੨',
    '\u1A92',
    '૨',
    '౨',
    '೨',
    '൨',
    '𑁨',
    '༢',
    '2',
    '2',
  ],
  [
    '3',
    '३',
    '3',
    '๓',
    '໓',
    '၃',
    '៣',
    '৩',
    '੩',
    '\u1A93',
    '૩',
    '౩',
    '೩',
    '൩',
    '𑁩',
    '༣',
    '3',
    '3',
  ],
  [
    '4',
    '४',
    '4',
    '๔',
    '໔',
    '၄',
    '៤',
    '৪',
    '੪',
    '\u1A94',
    '૪',
    '౪',
    '೪',
    '൪',
    '𑁪',
    '༤',
    '4',
    '4',
  ],
  [
    '5',
    '५',
    '5',
    '๕',
    '໕',
    '၅',
    '៥',
    '৫',
    '੫',
    '\u1A95',
    '૫',
    '౫',
    '೫',
    '൫',
    '𑁫',
    '༥',
    '5',
    '5',
  ],
  [
    '6',
    '६',
    '6',
    '๖',
    '໖',
    '၆',
    '៦',
    '৬',
    '੬',
    '\u1A96',
    '૬',
    '౬',
    '೬',
    '൬',
    '𑁬',
    '༦',
    '6',
    '6',
  ],
  [
    '7',
    '७',
    '7',
    '๗',
    '໗',
    '၇',
    '៧',
    '৭',
    '੭',
    '\u1A97',
    '૭',
    '౭',
    '೭',
    '൭',
    '𑁭',
    '༧',
    '7',
    '7',
  ],
  [
    '8',
    '८',
    '8',
    '๘',
    '໘',
    '၈',
    '៨',
    '৮',
    '੮',
    '\u1A98',
    '૮',
    '౮',
    '೮',
    '൮',
    '𑁮',
    '༨',
    '8',
    '8',
  ],
  [
    '9',
    '९',
    '9',
    '๙',
    '໙',
    '၉',
    '៩',
    '৯',
    '੯',
    '\u1A99',
    '૯',
    '౯',
    '೯',
    '൯',
    '𑁯',
    '༩',
    '9',
    '9',
  ],
];

const consos = [
  // velar stops
  [
    'ක',
    'क',
    'k',
    'ก',
    'ກ',
    'က',
    'ក',
    'ক',
    'ਕ',
    '\u1A20',
    'ક',
    'క',
    'ಕ',
    'ക',
    '𑀓',
    'ཀ',
    'к',
    'க',
  ],
  [
    'ඛ',
    'ख',
    'kh',
    'ข',
    'ຂ',
    'ခ',
    'ខ',
    'খ',
    'ਖ',
    '\u1A21',
    'ખ',
    'ఖ',
    'ಖ',
    'ഖ',
    '𑀔',
    'ཁ',
    'кх',
    'க²',
  ],
  [
    'ග',
    'ग',
    'g',
    'ค',
    'ຄ',
    'ဂ',
    'គ',
    'গ',
    'ਗ',
    '\u1A23',
    'ગ',
    'గ',
    'ಗ',
    'ഗ',
    '𑀕',
    'ག',
    'г',
    'க³',
  ],
  [
    'ඝ',
    'घ',
    'gh',
    'ฆ',
    '\u0E86',
    'ဃ',
    'ឃ',
    'ঘ',
    'ਘ',
    '\u1A25',
    'ઘ',
    'ఘ',
    'ಘ',
    'ഘ',
    '𑀖',
    'གྷ',
    'гх',
    'க⁴',
  ],
  [
    'ඞ',
    'ङ',
    'ṅ',
    'ง',
    'ງ',
    'င',
    'ង',
    'ঙ',
    'ਙ',
    '\u1A26',
    'ઙ',
    'ఙ',
    'ಙ',
    'ങ',
    '𑀗',
    'ང',
    'н̇',
    'ங',
  ],
  // palatal stops
  [
    'ච',
    'च',
    'c',
    'จ',
    'ຈ',
    'စ',
    'ច',
    'চ',
    'ਚ',
    '\u1A27',
    'ચ',
    'చ',
    'ಚ',
    'ച',
    '𑀘',
    'ཙ',
    'ч',
    'ச',
  ],
  [
    'ඡ',
    'छ',
    'ch',
    'ฉ',
    '\u0E89',
    'ဆ',
    'ឆ',
    'ছ',
    'ਛ',
    '\u1A28',
    'છ',
    'ఛ',
    'ಛ',
    'ഛ',
    '𑀙',
    'ཚ',
    'чх',
    'ச²',
  ],
  [
    'ජ',
    'ज',
    'j',
    'ช',
    'ຊ',
    'ဇ',
    'ជ',
    'জ',
    'ਜ',
    '\u1A29',
    'જ',
    'జ',
    'ಜ',
    'ജ',
    '𑀚',
    'ཛ',
    'дж',
    'ஜ',
  ],
  [
    'ඣ',
    'झ',
    'jh',
    'ฌ',
    '\u0E8C',
    'ဈ',
    'ឈ',
    'ঝ',
    'ਝ',
    '\u1A2B',
    'ઝ',
    'ఝ',
    'ಝ',
    'ഝ',
    '𑀛',
    'ཛྷ',
    'джх',
    'ஜ²',
  ],
  [
    'ඤ',
    'ञ',
    'ñ',
    'ญ',
    '\u0E8E',
    'ဉ',
    'ញ',
    'ঞ',
    'ਞ',
    '\u1A2C',
    'ઞ',
    'ఞ',
    'ಞ',
    'ഞ',
    '𑀜',
    'ཉ',
    'н̃',
    'ஞ',
  ],
  // retroflex stops
  [
    'ට',
    'ट',
    'ṭ',
    'ฏ',
    '\u0E8F',
    'ဋ',
    'ដ',
    'ট',
    'ਟ',
    '\u1A2D',
    'ટ',
    'ట',
    'ಟ',
    'ട',
    '𑀝',
    'ཊ',
    'т̣',
    'ட',
  ],
  [
    'ඨ',
    'ठ',
    'ṭh',
    'ฐ',
    '\u0E90',
    'ဌ',
    'ឋ',
    'ঠ',
    'ਠ',
    '\u1A2E',
    'ઠ',
    'ఠ',
    'ಠ',
    'ഠ',
    '𑀞',
    'ཋ',
    'т̣х',
    'ட²',
  ],
  [
    'ඩ',
    'ड',
    'ḍ',
    'ฑ',
    '\u0E91',
    'ဍ',
    'ឌ',
    'ড',
    'ਡ',
    '\u1A2F',
    'ડ',
    'డ',
    'ಡ',
    'ഡ',
    '𑀟',
    'ཌ',
    'д̣',
    'ட³',
  ],
  [
    'ඪ',
    'ढ',
    'ḍh',
    'ฒ',
    '\u0E92',
    'ဎ',
    'ឍ',
    'ঢ',
    'ਢ',
    '\u1A30',
    'ઢ',
    'ఢ',
    'ಢ',
    'ഢ',
    '𑀠',
    'ཌྷ',
    'д̣х',
    'ட⁴',
  ],
  [
    'ණ',
    'ण',
    'ṇ',
    'ณ',
    '\u0E93',
    'ဏ',
    'ណ',
    'ণ',
    'ਣ',
    '\u1A31',
    'ણ',
    'ణ',
    'ಣ',
    'ണ',
    '𑀡',
    'ཎ',
    'н̣',
    'ண',
  ],
  // dental stops
  [
    'ත',
    'त',
    't',
    'ต',
    'ຕ',
    'တ',
    'ត',
    'ত',
    'ਤ',
    '\u1A32',
    'ત',
    'త',
    'ತ',
    'ത',
    '𑀢',
    'ཏ',
    'т',
    'த',
  ],
  [
    'ථ',
    'थ',
    'th',
    'ถ',
    'ຖ',
    'ထ',
    'ថ',
    'থ',
    'ਥ',
    '\u1A33',
    'થ',
    'థ',
    'ಥ',
    'ഥ',
    '𑀣',
    'ཐ',
    'тх',
    'த²',
  ],
  [
    'ද',
    'द',
    'd',
    'ท',
    'ທ',
    'ဒ',
    'ទ',
    'দ',
    'ਦ',
    '\u1A34',
    'દ',
    'ద',
    'ದ',
    'ദ',
    '𑀤',
    'ད',
    'д',
    'த³',
  ],
  [
    'ධ',
    'ध',
    'dh',
    'ธ',
    '\u0E98',
    'ဓ',
    'ធ',
    'ধ',
    'ਧ',
    '\u1A35',
    'ધ',
    'ధ',
    'ಧ',
    'ധ',
    '𑀥',
    'དྷ',
    'дх',
    'த⁴',
  ],
  [
    'න',
    'न',
    'n',
    'น',
    'ນ',
    'န',
    'ន',
    'ন',
    'ਨ',
    '\u1A36',
    'ન',
    'న',
    'ನ',
    'ന',
    '𑀦',
    'ན',
    'н',
    'ந',
  ],
  // labial stops
  [
    'ප',
    'प',
    'p',
    'ป',
    'ປ',
    'ပ',
    'ប',
    'প',
    'ਪ',
    '\u1A38',
    'પ',
    'ప',
    'ಪ',
    'പ',
    '𑀧',
    'པ',
    'п',
    'ப',
  ],
  [
    'ඵ',
    'फ',
    'ph',
    'ผ',
    'ຜ',
    'ဖ',
    'ផ',
    'ফ',
    'ਫ',
    '\u1A39',
    'ફ',
    'ఫ',
    'ಫ',
    'ഫ',
    '𑀨',
    'ཕ',
    'пх',
    'ப²',
  ],
  [
    'බ',
    'ब',
    'b',
    'พ',
    'ພ',
    'ဗ',
    'ព',
    'ব',
    'ਬ',
    '\u1A3B',
    'બ',
    'బ',
    'ಬ',
    'ബ',
    '𑀩',
    'བ',
    'б',
    'ப³',
  ],
  [
    'භ',
    'भ',
    'bh',
    'ภ',
    '\u0EA0',
    'ဘ',
    'ភ',
    'ভ',
    'ਭ',
    '\u1A3D',
    'ભ',
    'భ',
    'ಭ',
    'ഭ',
    '𑀪',
    'བྷ',
    'бх',
    'ப⁴',
  ],
  [
    'ම',
    'म',
    'm',
    'ม',
    'ມ',
    'မ',
    'ម',
    'ম',
    'ਮ',
    '\u1A3E',
    'મ',
    'మ',
    'ಮ',
    'മ',
    '𑀫',
    'མ',
    'м',
    'ம',
  ],
  // liquids, fricatives, etc.
  [
    'ය',
    'य',
    'y',
    'ย',
    'ຍ',
    'ယ',
    'យ',
    'য',
    'ਯ',
    '\u1A3F',
    'ય',
    'య',
    'ಯ',
    'യ',
    '𑀬',
    'ཡ',
    'й',
    'ய',
  ],
  [
    'ර',
    'र',
    'r',
    'ร',
    'ຣ',
    'ရ',
    'រ',
    'র',
    'ਰ',
    '\u1A41',
    'ર',
    'ర',
    'ರ',
    'ര',
    '𑀭',
    'ར',
    'р',
    'ர',
  ],
  [
    'ල',
    'ल',
    'l',
    'ล',
    'ລ',
    'လ',
    'ល',
    'ল',
    'ਲ',
    '\u1A43',
    'લ',
    'ల',
    'ಲ',
    'ല',
    '𑀮',
    'ལ',
    'л',
    'ல',
  ],
  [
    'ළ',
    'ळ',
    'ḷ',
    'ฬ',
    '\u0EAC',
    'ဠ',
    'ឡ',
    'ল়',
    'ਲ਼',
    '\u1A4A',
    'ળ',
    'ళ',
    'ಳ',
    'ള',
    '𑀴',
    'ལ༹',
    'л̣',
    'ள',
  ],
  [
    'ව',
    'व',
    'v',
    'ว',
    'ວ',
    'ဝ',
    'វ',
    'ৰ',
    'ਵ',
    '\u1A45',
    'વ',
    'వ',
    'ವ',
    'വ',
    '𑀯',
    'ཝ',
    'в',
    'வ',
  ],
  [
    'ස',
    'स',
    's',
    'ส',
    'ສ',
    'သ',
    'ស',
    'স',
    'ਸ',
    '\u1A48',
    'સ',
    'స',
    'ಸ',
    'സ',
    '𑀲',
    'ས',
    'с',
    'ஸ',
  ],
  [
    'හ',
    'ह',
    'h',
    'ห',
    'ຫ',
    'ဟ',
    'ហ',
    'হ',
    'ਹ',
    '\u1A49',
    'હ',
    'హ',
    'ಹ',
    'ഹ',
    '𑀳',
    'ཧ',
    'х',
    'ஹ',
  ],
];

const vowels = [
  // dependent vowel signs 1A6E-1A63
  [
    'ා',
    'ा',
    'ā',
    'า',
    'າ',
    'ာ',
    'ា',
    'া',
    'ਾ',
    '\u1A63',
    'ા',
    'ా',
    'ಾ',
    'ാ',
    '𑀸',
    '\u0F71',
    'а̄',
    'ா',
  ],
  [
    'ි',
    'ि',
    'i',
    '\u0E34',
    '\u0EB4',
    'ိ',
    'ិ',
    'ি',
    'ਿ',
    '\u1A65',
    'િ',
    'ి',
    'ಿ',
    'ി',
    '𑀺',
    '\u0F72',
    'и',
    'ி',
  ],
  [
    'ී',
    'ी',
    'ī',
    '\u0E35',
    '\u0EB5',
    'ီ',
    'ី',
    'ী',
    'ੀ',
    '\u1A66',
    'ી',
    'ీ',
    'ೀ',
    'ീ',
    '𑀻',
    '\u0F71\u0F72',
    'ӣ',
    'ீ',
  ],
  [
    'ු',
    'ु',
    'u',
    '\u0E38',
    '\u0EB8',
    'ု',
    'ុ',
    'ু',
    'ੁ',
    '\u1A69',
    'ુ',
    'ు',
    'ು',
    'ു',
    '𑀼',
    '\u0F74',
    'у',
    'ு',
  ],
  [
    'ූ',
    'ू',
    'ū',
    '\u0E39',
    '\u0EB9',
    'ူ',
    'ូ',
    'ূ',
    'ੂ',
    '\u1A6A',
    'ૂ',
    'ూ',
    'ೂ',
    'ൂ',
    '𑀽',
    '\u0F71\u0F74',
    'ӯ',
    'ூ',
  ],
  [
    'ෙ',
    'े',
    'e',
    'เ',
    'ເ',
    'ေ',
    'េ',
    'ে',
    'ੇ',
    '\u1A6E',
    'ે',
    'ే',
    'ೇ',
    'േ',
    '𑁂',
    '\u0F7A',
    'е',
    'ே',
  ], //for th/lo - should appear in front
  [
    'ො',
    'ो',
    'o',
    'โ',
    'ໂ',
    'ော',
    'ោ',
    'ো',
    'ੋ',
    '\u1A6E\u1A63',
    'ો',
    'ో',
    'ೋ',
    'ോ',
    '𑁄',
    '\u0F7C',
    'о',
    'ோ',
  ], //for th/lo - should appear in front
];
const sinhalaConsonantRange = 'ක-ෆ';
const thaiConsonantRange = 'ก-ฮ';
const laoConsonantRange = 'ກ-ຮ';
const myanmarConsonantRange = 'က-ဠ';

String beautifySinhala(String text, {Script? script, String rendType = ''}) {
  // change joiners before U+0DBA Yayanna and U+0DBB Rayanna to Virama + ZWJ
  return text.replaceAllMapped(
    RegExp('\u0DCA([\u0DBA\u0DBB])'),
    (match) => '\u0DCA\u200D${match.group(1)}',
  );
}

String unbeautifySinhala(String text, {Script? script}) {
  // long vowels replaced by short vowels as sometimes people type long vowels by mistake
  text = text.replaceAll('ඒ', 'එ').replaceAll('ඕ', 'ඔ');
  return text.replaceAll('ේ', 'ෙ').replaceAll('ෝ', 'ො');
}

String beautifyMyanmar(String text, {Script? script, String rendType = ''}) {
  // new unicode 5.1 spec https://www.unicode.org/notes/tn11/UTN11_3.pdf
  text = text.replaceAll('[,;]', '၊'); // comma/semicolon -> single line
  text = text.replaceAll(
    '[\u2026\u0964\u0965]+',
    '။',
  ); // ellipsis/danda/double danda -> double line
  text = text.replaceAll('ဉ\u1039ဉ', 'ည'); // kn + kna has a single char
  text = text.replaceAll(
    'သ\u1039သ',
    'ဿ',
  ); // s + sa has a single char (great sa)
  text = text.replaceAllMapped(
    RegExp('င္([က-ဠ])'),
    (match) => 'င\u103A္${match.group(1)}',
  ); // kinzi - ඞ + al
  text = text.replaceAll('္ယ', 'ျ'); // yansaya  - yapin
  text = text.replaceAll('္ရ', 'ြ'); // rakar - yayit
  text = text.replaceAll('္ဝ', 'ွ'); // al + wa - wahswe
  text = text.replaceAll('္ဟ', 'ှ'); // al + ha - hahto
  // following code for tall aa is from https://www.facebook.com/pndaza.mlm
  text = text.replaceAllMapped(
    RegExp('([ခဂငဒပဝ]ေ?)\u102c'),
    (match) => "${match.group(1)}\u102b",
  ); // aa to tall aa
  text = text.replaceAllMapped(
    RegExp('(က္ခ|န္ဒ|ပ္ပ|မ္ပ)(ေ?)\u102b'),
    (match) => "${match.group(1)}${match.group(2)}\u102c",
  ); // restore back tall aa to aa for some pattern
  text = text.replaceAllMapped(
    RegExp('(ဒ္ဓ|ဒွ)(ေ?)\u102c'),
    (match) => "${match.group(1)}${match.group(2)}\u102b",
  );
  return text.replaceAll('သင်္ဃ', 'သံဃ');
}

String unbeautifyMyanmar(String text, {Script? script}) {
  // reverse of beautify above
  text = text.replaceAll('\u102B', 'ာ');
  text = text.replaceAll('ှ', '္ဟ'); // al + ha - hahto
  text = text.replaceAll('ွ', '္ဝ'); // al + wa - wahswe
  text = text.replaceAll('ြ', '္ရ'); // rakar - yayit
  text = text.replaceAll('ျ', '္ယ'); // yansaya  - yapin
  text = text.replaceAll('\u103A', ''); // kinzi
  text = text.replaceAll(
    'ဿ',
    'သ\u1039သ',
  ); // s + sa has a single char (great sa)
  text = text.replaceAll('ည', 'ဉ\u1039ဉ'); // nnga
  text = text.replaceAll(
    'သံဃ',
    'သင္ဃ',
  ); // nigghahita to ṅ for this word for searching - from Pn Daza

  text = text.replaceAll('၊', ','); // single line -> comma
  return text.replaceAll('။', '.'); // double line -> period
}

/// Each script need additional steps when rendering on screen
/// e.g. for sinh needs converting dandas/abbrev, removing spaces, and addition ZWJ

String beautifyCommon(String text, {Script? script, String rendType = ''}) {
  if (rendType == 'cen') {
    // remove double dandas around namo tassa
    text = text.replaceAll('॥', '');
  } else if (rendType.startsWith('ga')) {
    // in gathas, single dandas convert to semicolon, double to period
    text = text.replaceAll('।', ';');
    text = text.replaceAll('॥', '.');
  }

  // remove Dev abbreviation sign before an ellipsis. We don't want a 4th dot after pe.
  text = text.replaceAll('॰…', '…');

  text = text.replaceAll(
    '॰',
    '·',
  ); // abbre sign changed - prevent capitalization in notes
  text = text.replaceAll(
    '[।॥]',
    '.',
  ); //all other single and double dandas converted to period

  // cleanup punctuation 1) two spaces to one
  // 2) There should be no spaces before these punctuation marks.
  text = text.replaceAllMapped(
    RegExp('\\s([\\s,!;\\?\\.])'),
    (match) => '${match.group(1)}',
  );
  return text;
}

// for roman text only
String capitalize(String text, {Script? script, String rendType = ''}) {
  // not works for html text

  /*
  // the adding of <w> tags around the words before the beautification makes it harder - (?:<w>)? added
  // begining of a line
  text = text.replaceAllMapped(
      RegExp(r'^((?:<w>)?\S)'), (match) => match.group(1)!.toUpperCase());
  // beginning of sentence
  text = text.replaceAllMapped(RegExp(r'([\.\?]\s(?:<w>)?)(\S)'),
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}');
  // starting from a quote
  text = text.replaceAllMapped(RegExp(r'([\u201C‘](?:<w>)?)(\S)'),
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}');
*/
  return text;
}

String unCapitalize(String text, {Script? script}) => text.toLowerCase();
// for thai text - this can also be done in the convert stage

String swapEO(String text, {Script? script, String rendType = ''}) {
  if (script == Script.thai) {
    return text.replaceAllMapped(
      RegExp('([ก-ฮ])([เโ])'),
      (match) => '${match.group(2)}${match.group(1)}',
    );
  }
  if (script == Script.laos) {
    return text.replaceAllMapped(
      RegExp('([ກ-ຮ])([ເໂ])'),
      (match) => '${match.group(2)}${match.group(1)}',
    );
  }
  return text;
  // throw new Error(`Unsupported script ${script} for swap_e_o method.`);
}

// to be used when converting from
String unSwapEO(String text, {Script? script}) {
  if (script == Script.thai) {
    return text.replaceAllMapped(
      RegExp('([เโ])([ก-ฮ])'),
      (match) => '${match.group(2)}${match.group(1)}',
    );
  }
  if (script == Script.laos) {
    return text.replaceAllMapped(
      RegExp('([ເໂ])([ກ-ຮ])'),
      (match) => '${match.group(2)}${match.group(1)}',
    );
  }
  return text;
  // throw new Error(`Unsupported script ${script} for un_swap_e_o method.`);
}

// in thai pali these two characters have special glyphs (using the encoding used in the THSarabunNew Font)
String beautifyThai(String text, {Script? script}) {
  // 'iṃ' has a single unicode in thai
  text = text.replaceAll('\u0E34\u0E4D', '\u0E36');
  // disabel by pndaza to make sure encoding is same as tipitaka.org
  // text = text.replaceAll('ญ', '\uF70F');
  // text = text.replaceAll('ฐ', '\uF700');
  return text;
}

String unbeautifyThai(String text, {Script? script}) {
  // sometimes people use ฎ instead of the correct ฏ which is used in the tipitaka
  text = text.replaceAll('ฎ', 'ฏ');
  // 'iṃ' has a single unicode in thai which is split into two here
  text = text.replaceAll('\u0E36', '\u0E34\u0E4D');
  // disabel by pndaza to make sure encoding is same as tipitaka.org
  // text = text.replaceAll('\uF70F', 'ญ');
  // text = text.replaceAll('\uF700', 'ฐ');
  return text;
}

String unbeautifykhmer(String text, {Script? script}) {
  // 'iṃ' has a single unicode in khmer which is split into two here
  text = text.replaceAll('\u17B9', '\u17B7\u17C6');
  // end of word virama is different in khmer
  return text.replaceAll('\u17D1', '\u17D2');
}

/* zero-width joiners - replace both ways
['\u200C', ''], // ZWNJ (remove) not in sinh (or deva?)
['\u200D', ''], // ZWJ (remove) will be added when displaying*/
String cleanupZWJ(String inputText, {Script? script}) {
  return inputText.replaceAll(RegExp('\u200C|\u200D'), '');
}

String beautifyBrahmi(String text, {Script? script}) {
  // just replace deva danda with brahmi danda
  text = text.replaceAll('।', '𑁇');
  text = text.replaceAll('॥', '𑁈');
  return text.replaceAll('–', '𑁋');
}

String beautifyTham(String text, {Script? script}) {
  // todo - unbeautify needed
  text = text.replaceAll('\u1A60\u1A41', '\u1A55'); // medial ra - rakar
  text = text.replaceAll('\u1A48\u1A60\u1A48', '\u1A54'); // great sa - ssa
  text = text.replaceAll('।', '\u1AA8');
  return text.replaceAll('॥', '\u1AA9');
}

String beautifyTibet(String text, {Script? script}) {
  // copied form csharp - consider removing subjoined as it makes it hard to read
  // not adding the intersyllabic tsheg between "syllables" (done in csharp code) since no visible change
  text = text.replaceAll('।', '།'); // tibet dandas
  text = text.replaceAll('॥', '༎');
  // Iterate over all of the consonants, looking for tibetan halant + consonant.
  // Replace with the corresponding subjoined consonant (without halant)
  for (int i = 0; i <= 39; i++) {
    final String source =
        String.fromCharCode(0x0F84) + String.fromCharCode(0x0F40 + i);
    text = text.replaceAll(RegExp(source), String.fromCharCode(0x0F90 + i));
  }
  // exceptions: yya and vva use the "fixed-form subjoined consonants as the 2nd one
  text = text.replaceAll('\u0F61\u0FB1', '\u0F61\u0FBB'); //yya
  text = text.replaceAll('\u0F5D\u0FAD', '\u0F5D\u0FBA'); //vva

  // exceptions: jjha, yha and vha use explicit (visible) halant between
  text = text.replaceAll('\u0F5B\u0FAC', '\u0F5B\u0F84\u0F5C'); //jjha
  text = text.replaceAll('\u0F61\u0FB7', '\u0F61\u0F84\u0F67'); //yha
  return text.replaceAll('\u0F5D\u0FB7', '\u0F5D\u0F84\u0F67'); //vha
}

String unbeautifyTibet(String text, {Script? script}) {
  return text; // todo undo the subjoining done above
}

// ── Tamil ──────────────────────────────────────────────────────────────
// Convention from the tipitaka-xml Deva2Taml.cs conversion:
//  * aspirated/voiced consonants are marked with a superscript after the
//    consonant (² ³ ⁴): kha க², ga க³, bha ப⁴
//  * superscripts are moved after the following vowel sign / virama
//  * short எ/ஒ/ெ/ொ are used before a doubled consonant, long ஏ/ஓ/ே/ோ
//    elsewhere (Pāli e/o are long)
//  * dental ந becomes alveolar ன within a word, except before dental stops
//  * anusvara is written ங் and Tamil has no inherent vowel ("a" is
//    unwritten)
//
// Notes:
//  * ங் is ambiguous — it stands for both the anusvara and ṅ+virama (the
//    tipitaka-xml files write both identically), so converting Tamil back
//    to Sinhala turns saṅgha -> ஸங்க⁴ into සංඝ (the ඞ is lost). This
//    matches the reference conversion and is not a bug.
//  * the superscripts ² ³ ⁴ are NOT Tamil codepoints (²/³ fall in roman's
//    range, ⁴ in none), so mixed-script detection (convertFromMixed) splits
//    Tamil runs at them — the same is true of every superscript-using script
//    today.
const String _tamlVowelSigns = 'ா-ௌ'; // dependent vowel signs U+0BBE–U+0BCC

const Map<String, String> _tamlShortVowels = {
  'එ': 'எ', // independent e (short)
  'ඔ': 'ஒ', // independent o (short)
  'ෙ': 'ெ', // dependent e (short)
  'ො': 'ொ', // dependent o (short)
};

/// Replaces a Sinhala e/o directly followed by a doubled consonant
/// (consonant + virama + consonant) with the Tamil short vowels, mirroring
/// the placeholder regexes in Deva2Taml.cs. Runs on the Sinhala
/// intermediate before the character map; the inserted Tamil characters
/// pass through the map unchanged.
String _tamilShortEO(String text, Script script) {
  return text.replaceAllMapped(
    RegExp('([එඔෙො])([ක-හ]්[ක-හ])'),
    // group(1) is always one of the four keys (the regex char class)
    (match) => '${_tamlShortVowels[match.group(1)!]}${match.group(2)}',
  );
}

String beautifyTamil(String text, {Script? script, String rendType = ''}) {
  // move superscript (² ³ ⁴) after the following dependent vowel sign (க²ா → கா²)
  text = text.replaceAllMapped(
    RegExp('([²³⁴])([$_tamlVowelSigns])'),
    (match) => '${match.group(2)}${match.group(1)}',
  );
  // move superscript after the following virama (க²் → க்²)
  text = text.replaceAllMapped(
    RegExp('([²³⁴])(்)'),
    (match) => '${match.group(2)}${match.group(1)}',
  );
  // dental ந → alveolar ன when preceded by a Tamil letter/sign
  text = text.replaceAllMapped(
    RegExp('([\u0B82-\u0BCD²³⁴])ந'),
    (match) => '${match.group(1)}ன',
  );
  // ...except before a dental stop (ன்த → ந்த)
  return text.replaceAll('ன்த', 'ந்த');
}

String unbeautifyTamil(String text, {Script? script}) {
  // reverse the superscript moves above (கா² → க²ா, க்² → க²்)
  text = text.replaceAllMapped(
    RegExp('([$_tamlVowelSigns])([²³⁴])'),
    (match) => '${match.group(2)}${match.group(1)}',
  );
  text = text.replaceAllMapped(
    RegExp('(்)([²³⁴])'),
    (match) => '${match.group(2)}${match.group(1)}',
  );
  // alveolar ன back to dental ந (Pāli n is always dental)
  text = text.replaceAll('ன', 'ந');
  // short e/o (before doubled consonants) stand for Pāli long e/o
  return text
      .replaceAll('எ', 'ஏ')
      .replaceAll('ஒ', 'ஓ')
      .replaceAll('ெ', 'ே')
      .replaceAll('ொ', 'ோ');
}

List<Function> beautifyFunc(Script script) {
  switch (script) {
    case Script.sinhala:
      return [beautifySinhala, beautifyCommon];
    case Script.roman:
      return [beautifyCommon, capitalize];
    case Script.thai:
      return [swapEO, beautifyThai, beautifyCommon];
    case Script.laos:
      return [swapEO, beautifyCommon];
    case Script.myanmar:
      return [beautifyMyanmar, beautifyCommon];
    case Script.khmer:
      return [beautifyCommon];
    case Script.taitham:
      return [beautifyTham];
    case Script.gujarati:
      return [beautifyCommon];
    case Script.telugu:
      return [beautifyCommon];
    case Script.malayalam:
      return [beautifyCommon];
    case Script.brahmi:
      return [beautifyBrahmi, beautifyCommon];
    case Script.tibetan:
      return [beautifyTibet];
    case Script.cyrillic:
      return [beautifyCommon];
    case Script.tamil:
      return [beautifyTamil, beautifyCommon];
    default:
      return [];
  }
}

List<Function> unbeautifyFucn(Script script) {
  switch (script) {
    case Script.sinhala:
      return [cleanupZWJ, unbeautifySinhala];
    case Script.devanagari:
      // original deva script (from tipitaka.org) text has zwj
      return [cleanupZWJ];
    case Script.roman:
      return [unCapitalize];
    case Script.thai:
      return [unbeautifyThai, unSwapEO];
    case Script.laos:
      return [unSwapEO];
    case Script.khmer:
      return [unbeautifykhmer];
    case Script.myanmar:
      return [unbeautifyMyanmar];
    case Script.tibetan:
      return [unbeautifyTibet];
    case Script.tamil:
      return [unbeautifyTamil];
    default:
      return [];
  }
}

List<List<Object>> prepareHashMaps(
  int fromIndex,
  int toIndex, [
  bool useVowels = true,
]) {
  // The generated maps depend only on the (from, to, useVowels) triple, which is
  // constant per script. Building them is expensive (iterates the full
  // consonant/special/vowel tables and constructs Maps), so cache the result
  // instead of rebuilding it on every conversion call.
  final cacheKey = '$fromIndex-$toIndex-$useVowels';
  final cached = _hashMapCache[cacheKey];
  if (cached != null) return cached;

  var _vowels = useVowels ? vowels : [];
  final List<List<String>> fullAr = [...consos, ...specials, ..._vowels];
  final List<List<List<String>>> finalAr = [[], [], []];
  for (List<String> val in fullAr) {
    if (val[fromIndex].isNotEmpty) {
      // empty mapping - e.g in roman
      finalAr[val[fromIndex].length - 1].add([val[fromIndex], val[toIndex]]);
    }
  }
  finalAr.where((element) => element.isNotEmpty).toList();
  final result = List<List<Object>>.from(
    finalAr
        .where((element) => element.isNotEmpty)
        .toList()
        .map(
          (element) => [
            element[0][0].length,
            {for (var v in element) v[0]: v[1]},
          ],
        )
        .toList()
        .reversed,
  ); // longest is first
  _hashMapCache[cacheKey] = result;
  return result;
}

/// Memoized results of [prepareHashMaps], keyed by "from-to-useVowels".
final Map<String, List<List<Object>>> _hashMapCache = {};

String replaceByMaps(String inputText, List<List<Object>> hashMaps) {
  var outputAr = [];
  int start = 0;
  int length = inputText.length;
  // print('input count: $length');

  while (start < length) {
    var match = false;
    for (var element in hashMaps) {
      final len = element[0] as int;
      final hashMap = element[1] as Map<String, String>;
      final end = start + len <= length ? start + len : start + 1;
      // print('b: $start');
      // print('len: $len');
      final inChars = inputText.substring(start, end);
      // print('inChars: $inChars');
      // print(hashMap);
      if (hashMap.containsKey(inChars)) {
        outputAr.add(hashMap[inChars]); // note: can be empty string too
        match = true;
        start += len;
        break;
      }
    }
    if (!match) {
      // did not match the hashmaps
      outputAr.add(inputText[start]);
      start++;
    }
  }
  return outputAr.join('');
}

// for roman/cyrl text - insert 'a' after all consonants that are not followed by virama, dependent vowel or 'a'
// cyrillic mapping extracted from https://dhamma.ru/scripts/transdisp.js - -TODO capitalize cyrl too
String insertA(String text, Script script) {
  final a = (script == Script.cyrillic) ? '\u0430' : 'a'; // roman a or cyrl a
  text = text.replaceAllMapped(
    RegExp('([ක-ෆ])([^\u0DCF-\u0DDF\u0DCA$a])'),
    (match) => '${match.group(1)}$a${match.group(2)}',
  );
  text = text.replaceAllMapped(
    RegExp('([ක-ෆ])([^\u0DCF-\u0DDF\u0DCA$a])'),
    (match) => '${match.group(1)}$a${match.group(2)}',
  );
  // conso at the end of string not matched by regex above
  return text.replaceAllMapped(
    RegExp(r'([ක-ෆ])$'),
    (match) => '${match.group(1)}$a',
  );
}

const IV_TO_DV = {
  'අ': '',
  'ආ': 'ා',
  'ඉ': 'ි',
  'ඊ': 'ී',
  'උ': 'ු',
  'ඌ': 'ූ',
  'එ': 'ෙ',
  'ඔ': 'ො',
};
String removeA(String text, Script script) {
  text = text.replaceAllMapped(
    RegExp('([ක-ෆ])([^අආඉඊඋඌඑඔ\u0DCA])'),
    (match) => '${match.group(1)}\u0DCA${match.group(2)}',
  );
  // done twice to match successive hal
  text = text.replaceAllMapped(
    RegExp('([ක-ෆ])([^අආඉඊඋඌඑඔ\u0DCA])'),
    (match) => '${match.group(1)}\u0DCA${match.group(2)}',
  );
  text = text.replaceAllMapped(
    RegExp(r'([ක-ෆ])$'),
    (match) => '${match.group(1)}\u0DCA',
  ); // last conso not matched by above
  text = text.replaceAllMapped(
    RegExp(r'([ක-ෆ])([අආඉඊඋඌඑඔ])'),
    (match) => '${match.group(1)}${IV_TO_DV[match.group(2)]}',
  );
  return text;
}

// per ven anandajothi request
String fixMAbove(String text, Script script) {
  return text.replaceAll('ṁ', 'ං');
}

List<Function> convertToFunc(Script script) {
  switch (script) {
    case Script.sinhala:
      return [];
    case Script.roman:
      return [insertA, _convertTo];
    case Script.cyrillic:
      return [insertA, _convertTo];
    case Script.tamil:
      // short e/o before doubled consonants first, then the char map
      return [_tamilShortEO, _convertTo];
    default:
      return [_convertTo];
  }
}

List<Function> convertFromFunc(Script script) {
  switch (script) {
    case Script.sinhala:
      return [];
    case Script.roman:
      return [convertFromWV, fixMAbove, removeA];
    case Script.cyrillic:
      return [convertFromWV, removeA];
    default:
      return [_convertFrom];
  }
}

String _convertTo(String text, Script script) {
  final hashMaps = prepareHashMaps(Script.sinhala.index, script.index);
  return replaceByMaps(text, hashMaps);
}

String _convertFrom(String text, Script script) {
  // -TODO create maps initially and reuse them
  final hashMaps = prepareHashMaps(script.index, Script.sinhala.index);
  return replaceByMaps(text, hashMaps);
}

String convertFromWV(String text, Script script) {
  // without vowels for roman
  final hashMaps = prepareHashMaps(script.index, Script.sinhala.index, false);
  return replaceByMaps(text, hashMaps);
}

class TextProcessor {
  TextProcessor._();
  // convert from sinhala to another script
  static basicConvert(String text, Script script) {
    convertToFunc(script).forEach((func) => text = func(text, script));
    // (convert_to_func[script] || convert_to_func_default).forEach(func => text = func(text, script));
    return text;
  }

  // convert from another script to sinhala
  static basicConvertFrom(String text, Script script) {
    convertFromFunc(script).forEach((func) => text = func(text, script));
    // (convert_from_func[script] || convert_from_func_default).forEach(func => text = func(text, script));
    return beautify(text, Script.sinhala);
  }

  // script specific beautification
  static beautify(String text, Script script, {String rendType = ''}) {
    beautifyFunc(script).forEach((func) => text = func(text, script: script));
    // (beautify_func[script] || beautify_func_default).forEach(func => text = func(text, script, rendType));
    return text;
  }

  // from Sinhala to other script
  static convert(String text, Script script) {
    text = basicConvert(text, script);
    text = cleanupZWJ(text);
    return beautify(text, script);
  }

  // from other script to Sinhala - one script
  static convertFrom(String text, Script script) {
    // Pass the script so script-dependent un-beautification runs (e.g. the
    // Thai/Lao e/o vowel reordering in [unSwapEO]) actually applies.
    unbeautifyFucn(script).forEach((func) => text = func(text, script: script));
    return basicConvertFrom(text, script);
  }

  /// Whether [code] is one of the superscript markers ² ³ ⁴ used by the
  /// Tamil convention for aspirated/voiced consonants. ² (U+00B2) and ³
  /// (U+00B3) fall inside the Latin-1 (Roman) code point range, so script
  /// detection would otherwise split a Tamil word at every superscript and
  /// break the two-codepoint mappings (க² → ඛ, ப³ → බ).
  static bool _isTamilSuperscript(int code) =>
      code == 0x00B2 || code == 0x00B3 || code == 0x2074;

  // from other scripts (mixed) to Sinhala
  static convertFromMixed(String mixedText) {
    mixedText = cleanupZWJ(mixedText);
    Script? curScript;
    String run = '', output = '';
    for (int i = 0, length = mixedText.length; i < length; i++) {
      final code = mixedText.codeUnitAt(i);
      final newScript = _getScriptForCode(code);
      // A Tamil superscript marker stays glued to the surrounding non-Roman
      // run so pair mappings still apply (see [_isTamilSuperscript]).
      final isTamilMarker =
          _isTamilSuperscript(code) &&
          curScript != null &&
          curScript != Script.roman;
      if (!isTamilMarker && newScript != null && newScript != curScript) {
        output += _convertFromMixedRun(run, curScript);
        curScript = newScript;
        run = mixedText[i];
      } else {
        // Same script as before, a space, a superscript marker, or a
        // character with no known script — accumulate it into the current
        // run. Keeping unrecognized characters inside the run lets
        // multi-codepoint mappings (like Tamil "த⁴" → "ධ") still apply,
        // and avoids flushing an empty run through a null script.
        run += mixedText[i];
      }
    }
    output += _convertFromMixedRun(run, curScript);
    return output;
  }

  static String _convertFromMixedRun(String run, Script? script) {
    if (run.isEmpty) return '';
    if (script == null) return run; // unrecognized script: pass through
    return convertFrom(run, script);
  }
}

/// Returns true if [text] contains characters from a non-Latin Pali script
/// (e.g., Devanagari, Sinhala, Thai, Myanmar, Khmer, etc.).
bool isNonLatinScript(String text) {
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    final isLatin =
        (code >= 0x0020 && code <= 0x007E) || // Basic Latin
        (code >= 0x00A0 && code <= 0x00FF) || // Latin-1 Supplement
        (code >= 0x0100 && code <= 0x017F) || // Latin Extended-A
        (code >= 0x1E00 && code <= 0x1EFF); // Latin Extended Additional
    if (!isLatin) return true;
  }
  return false;
}

/// Converts Pali text from any script to Roman (IAST).
/// Falls back to the original text if conversion fails.
String convertToRomanPali(String text) {
  if (text.isEmpty) return text;
  // Only convert if the text contains non-Latin characters.
  if (isNonLatinScript(text)) {
    try {
      return TextProcessor.convert(
        TextProcessor.convertFromMixed(text),
        Script.roman,
      );
    } catch (_) {
      return text;
    }
  }
  return text;
}

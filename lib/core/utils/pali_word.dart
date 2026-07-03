import 'dart:math';

class PaliWord {
  PaliWord._();
  static final int _charCodeOfLetterA = 'a'.codeUnitAt(0);
  static final Map<String, int> paliCharacterOrder =
      'a,ā,i,ī,u,ū,e,o,k,kh,g,gh,ṅ,c,ch,j,jh,ñ,ṭ,ṭh,ḍ,ḍh,ṇ,t,th,d,dh,n,p,ph,b,bh,m,y,r,l,v,s,h,ḷ,ṃ'
          .split(',')
          .asMap()
          .map((index, value) => MapEntry(value, index + _charCodeOfLetterA));

  static const separator = '\n';
  static final reDoubleChar = RegExp('([kgcjṭḍtdpb])${separator}h');
  static List<String> toPaliCharacterArray(String text) => text
      .split('')
      .join(separator)
      .replaceAllMapped(reDoubleChar, (match) => '${match.group(1)}h')
      .split(separator);
  static int getCodeUnit(String character) =>
      paliCharacterOrder[character] ?? character.codeUnitAt(0);

  ///  compare two pali words for sorting.
  ///  Pali words must be encoded in roman script.
  
  static int compare(String a, String b) {
    var charactersOfA = toPaliCharacterArray(a);
    var charactersOfB = toPaliCharacterArray(b);
    var minLength = min(charactersOfA.length, charactersOfB.length);
    for (var i = 0; i < minLength; i++) {
      String charOfA = charactersOfA[i];
      String charOfB = charactersOfB[i];
      int charCodeUnitOfA = getCodeUnit(charOfA);
      int charCodeUnitOfB = getCodeUnit(charOfB);
      if (charCodeUnitOfA != charCodeUnitOfB) {
        return charCodeUnitOfA - charCodeUnitOfB;
      }
    }
    return charactersOfA.length - charactersOfB.length;
  }
}

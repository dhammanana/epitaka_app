import 'package:flutter/material.dart';

class DpdPalette extends ThemeExtension<DpdPalette> {
  const DpdPalette({
    required this.primary,
    required this.primaryAlt,
    required this.primaryText,
    required this.primaryTextDark,
    required this.light,
    required this.lightShade,
    required this.dark,
    required this.darkShade,
    required this.gray,
    required this.grayLight,
    required this.grayDark,
    required this.grayTransparent,
    required this.secondary,
    required this.freq,
    required this.accentRed,
    required this.accentRedDark,
    required this.accentGreen,
    required this.accentGreenDark,
    required this.accentOrange,
    required this.accentOrangeDark,
    required this.accentPurple,
    required this.accentPurpleDark,
    required this.accentBrown,
    required this.accentBrownDark,
    required this.shadowDefault,
    required this.shadowHover,
  });

  final Color primary;
  final Color primaryAlt;
  final Color primaryText;
  final Color primaryTextDark;
  final Color light;
  final Color lightShade;
  final Color dark;
  final Color darkShade;
  final Color gray;
  final Color grayLight;
  final Color grayDark;
  final Color grayTransparent;
  final Color secondary;
  final List<Color> freq;
  final Color accentRed;
  final Color accentRedDark;
  final Color accentGreen;
  final Color accentGreenDark;
  final Color accentOrange;
  final Color accentOrangeDark;
  final Color accentPurple;
  final Color accentPurpleDark;
  final Color accentBrown;
  final Color accentBrownDark;
  final List<BoxShadow> shadowDefault;
  final List<BoxShadow> shadowHover;

  @override
  DpdPalette copyWith({
    Color? primary,
    Color? primaryAlt,
    Color? primaryText,
    Color? primaryTextDark,
    Color? light,
    Color? lightShade,
    Color? dark,
    Color? darkShade,
    Color? gray,
    Color? grayLight,
    Color? grayDark,
    Color? grayTransparent,
    Color? secondary,
    List<Color>? freq,
    Color? accentRed,
    Color? accentRedDark,
    Color? accentGreen,
    Color? accentGreenDark,
    Color? accentOrange,
    Color? accentOrangeDark,
    Color? accentPurple,
    Color? accentPurpleDark,
    Color? accentBrown,
    Color? accentBrownDark,
    List<BoxShadow>? shadowDefault,
    List<BoxShadow>? shadowHover,
  }) {
    return DpdPalette(
      primary: primary ?? this.primary,
      primaryAlt: primaryAlt ?? this.primaryAlt,
      primaryText: primaryText ?? this.primaryText,
      primaryTextDark: primaryTextDark ?? this.primaryTextDark,
      light: light ?? this.light,
      lightShade: lightShade ?? this.lightShade,
      dark: dark ?? this.dark,
      darkShade: darkShade ?? this.darkShade,
      gray: gray ?? this.gray,
      grayLight: grayLight ?? this.grayLight,
      grayDark: grayDark ?? this.grayDark,
      grayTransparent: grayTransparent ?? this.grayTransparent,
      secondary: secondary ?? this.secondary,
      freq: freq ?? this.freq,
      accentRed: accentRed ?? this.accentRed,
      accentRedDark: accentRedDark ?? this.accentRedDark,
      accentGreen: accentGreen ?? this.accentGreen,
      accentGreenDark: accentGreenDark ?? this.accentGreenDark,
      accentOrange: accentOrange ?? this.accentOrange,
      accentOrangeDark: accentOrangeDark ?? this.accentOrangeDark,
      accentPurple: accentPurple ?? this.accentPurple,
      accentPurpleDark: accentPurpleDark ?? this.accentPurpleDark,
      accentBrown: accentBrown ?? this.accentBrown,
      accentBrownDark: accentBrownDark ?? this.accentBrownDark,
      shadowDefault: shadowDefault ?? this.shadowDefault,
      shadowHover: shadowHover ?? this.shadowHover,
    );
  }

  @override
  DpdPalette lerp(DpdPalette? other, double t) {
    if (other == null) return this;
    return DpdPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryAlt: Color.lerp(primaryAlt, other.primaryAlt, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      primaryTextDark: Color.lerp(primaryTextDark, other.primaryTextDark, t)!,
      light: Color.lerp(light, other.light, t)!,
      lightShade: Color.lerp(lightShade, other.lightShade, t)!,
      dark: Color.lerp(dark, other.dark, t)!,
      darkShade: Color.lerp(darkShade, other.darkShade, t)!,
      gray: Color.lerp(gray, other.gray, t)!,
      grayLight: Color.lerp(grayLight, other.grayLight, t)!,
      grayDark: Color.lerp(grayDark, other.grayDark, t)!,
      grayTransparent: Color.lerp(grayTransparent, other.grayTransparent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      freq: List.generate(
        freq.length,
        (i) => Color.lerp(freq[i], other.freq[i], t)!,
      ),
      accentRed: Color.lerp(accentRed, other.accentRed, t)!,
      accentRedDark: Color.lerp(accentRedDark, other.accentRedDark, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentGreenDark: Color.lerp(accentGreenDark, other.accentGreenDark, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentOrangeDark:
          Color.lerp(accentOrangeDark, other.accentOrangeDark, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      accentPurpleDark:
          Color.lerp(accentPurpleDark, other.accentPurpleDark, t)!,
      accentBrown: Color.lerp(accentBrown, other.accentBrown, t)!,
      accentBrownDark: Color.lerp(accentBrownDark, other.accentBrownDark, t)!,
      shadowDefault: t < 0.5 ? shadowDefault : other.shadowDefault,
      shadowHover: t < 0.5 ? shadowHover : other.shadowHover,
    );
  }
}

extension PaletteContext on BuildContext {
  DpdPalette get palette => Theme.of(this).extension<DpdPalette>()!;
}

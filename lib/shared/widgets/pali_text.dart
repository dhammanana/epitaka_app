import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/pali_text_utils.dart';
import '../../core/utils/pali_script_converter.dart';
import '../utils/html_text_parser.dart';

/// A [Text] replacement that automatically converts Pāli text to the user's
/// selected script and applies the correct font family.
///
/// [data] is the Pāli text in Roman script (with diacritics). It will be
/// converted to the target script according to the user's `paliScript` setting.
/// HTML tags in [data] are preserved during conversion so that `<b>pāli</b>`
/// does not get corrupted.
///
/// Example:
/// ```dart
/// // Before: Text(convertPaliToScript(text, script), style: ...)
/// // After:
/// PaliText(text, style: ...)
/// ```
class PaliText extends ConsumerWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final StrutStyle? strutStyle;
  final TextHeightBehavior? textHeightBehavior;
  final double? textScaleFactor;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;

  const PaliText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    this.strutStyle,
    this.textHeightBehavior,
    this.textScaleFactor,
    this.semanticsLabel,
    this.textWidthBasis,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider.select((s) => s.paliScript));
    final converted = convertPaliToScriptPreservingHtml(data, script);
    final fontFamily = scriptFontFamily(script);
    final effectiveStyle = style?.copyWith(fontFamily: fontFamily) ??
        TextStyle(fontFamily: fontFamily);

    return Text(
      converted,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      textDirection: textDirection,
      strutStyle: strutStyle,
      textHeightBehavior: textHeightBehavior,
      textScaleFactor: textScaleFactor,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
    );
  }
}

/// Like [PaliText] but renders Pāli text that may contain HTML tags
/// (`<b>`, `<i>`, `<u>`, `<h1-6>`, `<br>`).
///
/// Internally it converts the Pāli script (preserving HTML tags) and then
/// parses the HTML into Flutter [InlineSpan]s for rich-text display.
///
/// Example:
/// ```dart
/// // Before:
/// HtmlTextParser.richText(
///   convertPaliToScriptPreservingHtml(line.paliText, script),
///   AppTypography.bodyPali.copyWith(color: paliColor),
/// )
/// // After:
/// PaliHtmlText(line.paliText, style: bodyPali.copyWith(color: paliColor))
/// ```
class PaliHtmlText extends ConsumerWidget {
  final String html;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const PaliHtmlText(
    this.html, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider.select((s) => s.paliScript));
    final converted = convertPaliToScriptPreservingHtml(html, script);
    final fontFamily = scriptFontFamily(script);
    final effectiveStyle = style?.copyWith(fontFamily: fontFamily) ??
        TextStyle(fontFamily: fontFamily);

    return HtmlTextParser.richText(
      converted,
      effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// Non-ConsumerWidget variant of [PaliText] for use in widgets that do not
/// have access to [WidgetRef] but can look up the [script] themselves.
///
/// This is a plain function that converts text to the given script and sets
/// the font family. Use it when you already have the [script] value and just
/// need a stateless widget.
///
/// Example:
/// ```dart
/// PaliText.static(nikaya.name, script, style: ...)
/// ```
class PaliTextStatic extends StatelessWidget {
  final String data;
  final Script? script;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const PaliTextStatic(
    this.data,
    this.script, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final s = script ?? Script.roman;
    final converted = convertPaliToScriptPreservingHtml(data, s);
    final fontFamily = scriptFontFamily(s);
    final effectiveStyle = style?.copyWith(fontFamily: fontFamily) ??
        TextStyle(fontFamily: fontFamily);

    return Text(
      converted,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

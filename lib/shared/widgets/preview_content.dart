import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/pali_script_converter.dart';
import '../../core/utils/pali_text_utils.dart';
import 'pali_text.dart';
import '../utils/html_text_parser.dart';

/// A single line of preview content.
class PreviewLineData {
  final int paraId;
  final int lineId;
  final String pali;
  final Map<String, String> translations;

  const PreviewLineData({
    required this.paraId,
    required this.lineId,
    required this.pali,
    this.translations = const {},
  });
}

/// Renders a list of Pāli + translation lines using the same typography
/// settings as the reader (LanguageTypography, color pairs, script).
///
/// Used by [ParagraphPreviewSheet] (book-link sections and search previews).
/// Highlights the matched paragraph with a left border + background tint.
/// Supports optional Pāli word tap via [onPaliWordTap] (e.g. dictionary lookup).
class PreviewContent extends ConsumerWidget {
  final List<PreviewLineData> lines;
  final int? highlightParaId;
  final int? firstSnippetIndex;
  final String? paliSnippet;
  /// Called when the user double-taps on a Pāli text (opens dictionary).
  final ValueChanged<String>? onPaliWordTap;

  const PreviewContent({
    super.key,
    required this.lines,
    this.highlightParaId,
    this.firstSnippetIndex,
    this.paliSnippet,
    this.onPaliWordTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final settings = ref.watch(settingsProvider);
    final paliColor = settings.paliColorPair.resolve(brightness);
    final transColor = settings.translationColorPair.resolve(brightness);
    final script = settings.paliScript;
    final paliTypo = settings.typography.pali;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: lines.asMap().entries.map((entry) {
        final index = entry.key;
        final line = entry.value;
        final isMatch = line.paraId == highlightParaId;
        final isFirstSnippetLine =
            isMatch && firstSnippetIndex != null && index == firstSnippetIndex;

        final isNewPara =
            index == 0 || line.paraId != lines[index - 1].paraId;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Paragraph gap
            if (isNewPara && index > 0) const SizedBox(height: 12),

            // Match-highlighted paragraph block
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isMatch
                    ? colors.primaryContainer.withValues(alpha: 0.25)
                    : null,
                border: isMatch
                    ? Border(
                        left: BorderSide(
                          color: colors.primary,
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pāli text
                  if (isFirstSnippetLine && paliSnippet != null &&
                      paliSnippet!.isNotEmpty)
                    _buildPaliSnippet(paliSnippet!, paliColor,
                        paliTypo, script)
                  else if (line.pali.isNotEmpty)
                    _buildPaliLine(line.pali, paliColor, paliTypo, script),
                  // Translations
                  ...line.translations.entries.map((tEntry) {
                    if (tEntry.value.isEmpty) return const SizedBox.shrink();
                    final langTypo = settings.typography.languageOverrides[tEntry.key];
                    return _buildTranslationLine(
                      tEntry.value,
                      transColor,
                      langTypo,
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPaliSnippet(
    String snippet,
    Color paliColor,
    LanguageTypography paliTypo,
    Script script,
  ) {
    // Convert the snippet to match the target script (preserving HTML <mark> tags)
    final converted = convertPaliToScriptPreservingHtml(snippet, script);
    final effectiveColor = paliTypo.effectiveColor(paliColor);
    final baseStyle = TextStyle(
      fontFamily: scriptFontFamily(script),
      fontSize: paliTypo.fontSize,
      height: paliTypo.lineHeight,
      fontWeight: paliTypo.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: paliTypo.italic ? FontStyle.italic : FontStyle.normal,
      decoration:
          paliTypo.underline ? TextDecoration.underline : TextDecoration.none,
      color: effectiveColor,
    );

    return _buildTappablePali(
      child: HtmlTextParser.richText(
        converted,
        baseStyle,
        maxLines: null,
      ),
      paliText: snippet,
    );
  }

  Widget _buildPaliLine(
    String text,
    Color paliColor,
    LanguageTypography paliTypo,
    Script script,
  ) {
    final effectiveColor = paliTypo.effectiveColor(paliColor);
    final baseStyle = TextStyle(
      fontFamily: scriptFontFamily(script),
      fontSize: paliTypo.fontSize,
      height: paliTypo.lineHeight,
      fontWeight: paliTypo.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: paliTypo.italic ? FontStyle.italic : FontStyle.normal,
      decoration:
          paliTypo.underline ? TextDecoration.underline : TextDecoration.none,
      color: effectiveColor,
    );

    return _buildTappablePali(
      child: PaliHtmlText(text, style: baseStyle, maxLines: null),
      paliText: text,
    );
  }

  /// Wrap Pāli content in GestureDetector for double-tap dictionary lookup.
  Widget _buildTappablePali({
    required Widget child,
    required String paliText,
  }) {
    if (onPaliWordTap == null) return child;

    return GestureDetector(
      onDoubleTap: () {
        // Extract meaningful Pāli words from the text
        final words = paliText
            .replaceAll(RegExp(r'<[^>]*>'), ' ')  // strip HTML tags
            .replaceAll(RegExp(r'[^\wāīūṅñṭḍṇḷṃĀĪŪṄÑṬḌṆḶṀ\s]'), ' ')
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 2)
            .toList();
        if (words.isNotEmpty) {
          onPaliWordTap!(words.first);
        }
      },
      child: child,
    );
  }

  Widget _buildTranslationLine(
    String text,
    Color transColor,
    LanguageTypography? langTypo,
  ) {
    final effectiveFallback = transColor;
    final style = langTypo != null
        ? langTypo.toTextStyle(fallbackColor: effectiveFallback)
        : TextStyle(
            fontFamily: AppTypography.translationFont,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 28 / 17,
            color: effectiveFallback.withValues(alpha: 0.85),
          );

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: HtmlTextParser.richText(
        text,
        style,
        maxLines: null,
      ),
    );
  }
}

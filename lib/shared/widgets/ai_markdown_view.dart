/// Markdown rendering with tappable `[book:para:line]` citations.
///
/// Extracted from the Vimaṃsa (AI Q&A) chat bubble so other features — e.g.
/// the outline's study-guide view — render the same markdown the same way,
/// turning every citation into a chip the user can tap to preview the
/// quoted passage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Custom inline syntax that matches [book_id:para_id:line_id] citations.
class CitationInlineSyntax extends md.InlineSyntax {
  CitationInlineSyntax() : super(r'\[([a-zA-Z0-9_.-]+):(\d+):(\d+)(?:-(\d+))?\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final bookId = match.group(1)!;
    final paraId = match.group(2)!;
    // Use the first line_id; ignore the optional range end.
    final lineId = match.group(3)!;
    parser.addNode(md.Element.text('citation', '$bookId:$paraId:$lineId'));
    return true;
  }
}

/// Custom Markdown widget builder that renders citation elements as
/// clickable inline chips.
class CitationMarkdownBuilder extends MarkdownElementBuilder {
  final void Function(String bookId, int paraId, int lineId) onCitationTap;

  CitationMarkdownBuilder({required this.onCitationTap});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'citation') return null;
    final ref = element.textContent;
    final parts = ref.split(':');
    if (parts.length < 3) return null;
    final bookId = parts[0];
    final paraId = int.tryParse(parts[1]) ?? 0;
    final lineId = int.tryParse(parts[2]) ?? 1;

    final color = preferredStyle?.color ?? Colors.blue;
    return GestureDetector(
      onTap: () => onCitationTap(bookId, paraId, lineId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_quote, size: 10, color: color),
            const SizedBox(width: 2),
            Text(
              '$bookId §$paraId:$lineId',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders [data] as markdown with [book:para:line] citations turned into
/// tappable chips ([onCitationTap]). Wrapped in a [SelectionArea] so the
/// reader can copy passages.
class AiMarkdownView extends StatelessWidget {
  final String data;

  /// Called when a citation chip is tapped.
  final void Function(String bookId, int paraId, int lineId) onCitationTap;

  const AiMarkdownView({
    super.key,
    required this.data,
    required this.onCitationTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final inlineSyntaxes = <md.InlineSyntax>[CitationInlineSyntax()];

    return SelectionArea(
      child: Markdown(
        data: data,
        selectable: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        extensionSet: md.ExtensionSet(md.ExtensionSet.gitHubWeb.blockSyntaxes, [
          ...md.ExtensionSet.gitHubWeb.inlineSyntaxes,
          ...inlineSyntaxes,
        ]),
        builders: {
          'citation': CitationMarkdownBuilder(onCitationTap: onCitationTap),
        },
        styleSheet: markdownStyleSheet(colors),
        onTapLink: (text, href, title) {
          // Regular links (if any) are handled by the caller if needed.
        },
      ),
    );
  }
}

/// The markdown theme shared by every AI-markdown surface so study guides
/// and chat answers look identical.
MarkdownStyleSheet markdownStyleSheet(ColorScheme colors) {
  return MarkdownStyleSheet(
    p: TextStyle(color: colors.onSurface, fontSize: 15, height: 1.6),
    h1: TextStyle(
      color: colors.onSurface,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      height: 1.4,
    ),
    h2: TextStyle(
      color: colors.onSurface,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      height: 1.4,
    ),
    h3: TextStyle(
      color: colors.onSurface,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    strong: TextStyle(
      color: colors.onSurface,
      fontWeight: FontWeight.bold,
      fontSize: 15,
      height: 1.6,
    ),
    em: TextStyle(
      color: colors.onSurface,
      fontStyle: FontStyle.italic,
      fontSize: 15,
      height: 1.6,
    ),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: colors.primary.withValues(alpha: 0.4), width: 3),
      ),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.15),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    blockquote: TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 14,
      height: 1.5,
      fontStyle: FontStyle.italic,
    ),
    code: TextStyle(
      color: colors.primary,
      fontSize: 13,
      fontFamily: 'monospace',
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
    ),
    codeblockDecoration: BoxDecoration(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    listBullet: TextStyle(color: colors.primary, fontSize: 15),
    a: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
    ),
    tableBorder: TableBorder.all(
      color: colors.outlineVariant.withValues(alpha: 0.3),
    ),
    tableHead: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
    tableBody: TextStyle(color: colors.onSurfaceVariant),
    del: TextStyle(
      color: colors.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
    ),
  );
}

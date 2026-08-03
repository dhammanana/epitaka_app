library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../models/ai_qa_models.dart';
import '../providers/ai_qa_provider.dart';
import '../services/citation_quickview.dart';

/// Custom inline syntax that matches [book_id:para_id:line_id] citations.
class _CitationSyntax extends md.InlineSyntax {
  _CitationSyntax() : super(r'\[([a-zA-Z0-9_.-]+):(\d+):(\d+)(?:-(\d+))?\]');

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
/// clickable inline links.
class _CitationBuilder extends MarkdownElementBuilder {
  final void Function(String bookId, int paraId, int lineId) onCitationTap;

  _CitationBuilder({required this.onCitationTap});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'citation') return null;
    final ref = element.textContent;
    final parts = ref.split(':');
    if (parts.length < 3) return null;
    final bookId = parts[0];
    final paraId = int.tryParse(parts[1]) ?? 0;
    final lineId = int.tryParse(parts[2]) ?? 1;

    return GestureDetector(
      onTap: () => onCitationTap(bookId, paraId, lineId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color:
              preferredStyle?.color?.withValues(alpha: 0.12) ??
              Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color:
                preferredStyle?.color?.withValues(alpha: 0.25) ??
                Colors.blue.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_quote,
              size: 10,
              color: preferredStyle?.color ?? Colors.blue,
            ),
            const SizedBox(width: 2),
            Text(
              '$bookId §$paraId:$lineId',
              style: TextStyle(
                color: preferredStyle?.color ?? Colors.blue,
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

/// Renders a single message bubble in the AI Q&A chat.
class AiQaMessageBubble extends ConsumerWidget {
  final AiQaMessage message;

  const AiQaMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final isPhone = ResponsiveBreakpoint.isPhone(context);
    // Read streaming text from the separate provider — only this bubble
    // rebuilds when streaming text changes, NOT the entire screen.
    final streamingMessageId = ref.watch(streamingMessageIdProvider);
    final isCurrentlyStreaming =
        message.id == streamingMessageId && message.isStreaming;

    // Only show tool-calls-only view when NOT streaming (i.e. during the
    // tool loop, before the answer model starts generating). Once streaming
    // text arrives, show the message bubble with the streaming content.
    final isAssistantWithToolCalls =
        !isUser &&
        message.toolCalls.isNotEmpty &&
        message.text.isEmpty &&
        !isCurrentlyStreaming;
    final streamingText = isCurrentlyStreaming
        ? ref.watch(streamingTextProvider)
        : null;
    final displayText =
        isCurrentlyStreaming &&
            streamingText != null &&
            streamingText.isNotEmpty
        ? streamingText
        : message.text;

    // On phones: minimal margins, near-full width to maximize content.
    // On tablet/desktop: more generous margins and max-width for a nicer look.
    final horizontalMargin = isPhone ? 4.0 : AppDimensions.marginMobile;
    final oppositeMargin = isPhone ? 4.0 : AppDimensions.marginMobile + 20;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isUser ? oppositeMargin : horizontalMargin,
        isPhone ? 2 : 4,
        isUser ? horizontalMargin : oppositeMargin,
        isPhone ? 2 : 4,
      ),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Tool calls log (for thinking/loading state)
          if (isAssistantWithToolCalls)
            _buildToolCallsLog(context, ref, colors),

          // Thinking indicator
          if (message.isThinking) _buildThinkingIndicator(context, colors),

          // Message bubble
          if (!isAssistantWithToolCalls)
            _buildMessageBubble(
              context,
              ref,
              isUser,
              isCurrentlyStreaming,
              displayText,
              colors,
            ),

          // Citation buttons (only when streaming is complete)
          if (message.citations.isNotEmpty && !isCurrentlyStreaming)
            _buildCitationsBar(context, ref, colors),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    WidgetRef ref,
    bool isUser,
    bool isStreaming,
    String displayText,
    ColorScheme colors,
  ) {
    final isPhone = ResponsiveBreakpoint.isPhone(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isUser
            ? colors.primary.withValues(alpha: 0.12)
            : colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomRight: isUser ? const Radius.circular(4) : null,
          bottomLeft: !isUser ? const Radius.circular(4) : null,
        ),
      ),
      constraints: BoxConstraints(
        maxWidth: isPhone
            ? MediaQuery.of(context).size.width * 0.97
            : MediaQuery.of(context).size.width * 0.85,
      ),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          isUser
              ? _buildUserText(displayText, colors)
              : _buildAssistantContent(
                  context,
                  ref,
                  displayText,
                  isStreaming,
                  colors,
                ),
          // Copy button at the bottom of the bubble
          const SizedBox(height: 6),
          _CopyButton(text: displayText),
        ],
      ),
    );
  }

  Widget _buildToolCallsLog(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colors,
  ) {
    final loc = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 14,
                color: colors.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                loc.researchingLabel,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.primary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...message.toolCalls.map(
            (call) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_right,
                    size: 14,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      call.resultSummary,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator(BuildContext context, ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            loc.thinkingLabel,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserText(String text, ColorScheme colors) {
    return Text(
      text,
      style: AppTypography.bodyTranslation.copyWith(
        color: colors.onSurface,
        fontSize: 15,
        height: 1.5,
      ),
    );
  }

  Widget _buildAssistantContent(
    BuildContext context,
    WidgetRef ref,
    String displayText,
    bool isStreaming,
    ColorScheme colors,
  ) {
    // If we are streaming but have no text yet, show a "Generating..." indicator
    if (isStreaming && displayText.isEmpty) {
      return _buildGeneratingIndicator(context, colors);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isStreaming)
          // ── LIGHTWEIGHT STREAMING: plain Text — no markdown parsing ──
          _buildStreamingText(context, ref, displayText, colors)
        else
          // ── FINAL ANSWER: proper markdown with selection ──
          _buildMarkdown(context, ref, displayText, colors),

        // Small stream indicator at bottom while tokens arrive
        if (isStreaming)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  /// Lightweight streaming text renderer — just pure text with citation
  /// highlights. Avoids expensive markdown parsing on every token.
  Widget _buildStreamingText(
    BuildContext context,
    WidgetRef ref,
    String text,
    ColorScheme colors,
  ) {
    // Parse [book_id:para_id:line_id] or [book_id:para_id:line1-line2] citations
    final citationRegex = RegExp(r'\[([a-zA-Z0-9_.-]+):(\d+):(\d+)(?:-(\d+))?\]');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in citationRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        );
      }

      final bookId = match.group(1)!;
      final paraId = int.tryParse(match.group(2)!) ?? 0;
      final lineId = int.tryParse(match.group(3)!) ?? 1;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _openCitation(context, ref, bookId, paraId, lineId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_quote, size: 10, color: colors.primary),
                  const SizedBox(width: 2),
                  Text(
                    '$bookId §$paraId:$lineId',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: colors.onSurface, fontSize: 15, height: 1.6),
        ),
      );
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _buildGeneratingIndicator(BuildContext context, ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            loc.generatingAnswer,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Full markdown rendering — only used when streaming is complete.
  Widget _buildMarkdown(
    BuildContext context,
    WidgetRef ref,
    String text,
    ColorScheme colors,
  ) {
    final inlineSyntaxes = <md.InlineSyntax>[_CitationSyntax()];

    return SelectionArea(
      child: Markdown(
        data: text,
        selectable: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        extensionSet: md.ExtensionSet(md.ExtensionSet.gitHubWeb.blockSyntaxes, [
          ...md.ExtensionSet.gitHubWeb.inlineSyntaxes,
          ...inlineSyntaxes,
        ]),
        builders: {
          'citation': _CitationBuilder(
            onCitationTap: (bookId, paraId, lineId) =>
                _openCitation(context, ref, bookId, paraId, lineId),
          ),
        },
        styleSheet: _markdownStyleSheet(colors),
        onTapLink: (text, href, title) {
          // Handle regular links if needed
        },
      ),
    );
  }

  static MarkdownStyleSheet _markdownStyleSheet(ColorScheme colors) {
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
          left: BorderSide(
            color: colors.primary.withValues(alpha: 0.4),
            width: 3,
          ),
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
      tableHead: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.bold,
      ),
      tableBody: TextStyle(color: colors.onSurfaceVariant),
      del: TextStyle(
        color: colors.onSurfaceVariant,
        decoration: TextDecoration.lineThrough,
      ),
    );
  }

  Widget _buildCitationsBar(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colors,
  ) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 12,
                color: colors.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                loc.citationsCount(message.citations.length),
                style: AppTypography.labelSmall.copyWith(
                  color: colors.primary.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: message.citations.map((citation) {
              return ActionChip(
                avatar: Icon(
                  Icons.open_in_new,
                  size: 12,
                  color: colors.primary,
                ),
                label: Text(
                  citation.bookName != null
                      ? '${citation.bookName} §${citation.paraId}:${citation.lineId}'
                      : '${citation.bookId} §${citation.paraId}:${citation.lineId}',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => _openCitation(
                  context,
                  ref,
                  citation.bookId,
                  citation.paraId,
                  citation.lineId,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                side: BorderSide.none,
                backgroundColor: colors.primaryContainer.withValues(alpha: 0.2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _openCitation(
    BuildContext context,
    WidgetRef ref,
    String bookId,
    int paraId,
    int lineId,
  ) {
    // Open a quickview preview of the cited passage instead of jumping
    // straight to the reader; the user can open the book from there.
    showCitationQuickview(
      context,
      ref,
      bookId: bookId,
      bookName: bookId,
      paraId: paraId,
      lineId: lineId,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  COPY BUTTON
// ═══════════════════════════════════════════════════════════════════════════

/// Small icon button at the bottom of each message bubble. Copies the
/// message text to the clipboard and briefly shows "Copied!" feedback.
class _CopyButton extends StatelessWidget {
  final String text;

  const _CopyButton({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      icon: const Icon(Icons.content_copy, size: 13),
      color: colors.onSurfaceVariant.withValues(alpha: 0.35),
      tooltip: AppLocalizations.of(context).copyMessage,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).copied),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }
}

library;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/widgets/ai_markdown_view.dart';
import '../models/ai_qa_models.dart';
import '../providers/ai_qa_provider.dart';
import '../services/ai_response_share_service.dart';
import '../services/citation_quickview.dart';

/// Renders a single message bubble in the AI Q&A chat.
class AiQaMessageBubble extends ConsumerWidget {
  final AiQaMessage message;
  final VoidCallback? onEdit;
  final VoidCallback? onRetry;

  const AiQaMessageBubble({
    super.key,
    required this.message,
    this.onEdit,
    this.onRetry,
  });

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

          // Action buttons below bubble
          if (!isAssistantWithToolCalls &&
              !isCurrentlyStreaming &&
              !message.isThinking)
            _buildActionButtons(context, ref, isUser, displayText, colors),

          // Citation buttons (only when streaming is complete)
          if (message.citations.isNotEmpty && !isCurrentlyStreaming)
            _buildCitationsBar(context, ref, colors),

          // Response time at the end (assistant only, once complete)
          if (!isUser &&
              !isAssistantWithToolCalls &&
              !isCurrentlyStreaming &&
              !message.isThinking &&
              message.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                DateFormat.yMd().add_Hm().format(message.timestamp),
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ),
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
        ],
      ),
    );
  }

  /// Research progress log (anx-reader style): collapsible thinking panel
  /// with per-step status colours — green = ok, red = failed, orange =
  /// still running. Keeps long tool chains readable.
  Widget _buildToolCallsLog(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colors,
  ) {
    final loc = AppLocalizations.of(context);
    final failed = message.toolCalls.any(
      (c) => c.resultSummary.startsWith('❌'),
    );
    final statusColor = failed
        ? colors.error
        : colors.primary.withValues(alpha: 0.7);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        dense: true,
        initiallyExpanded: message.isThinking,
        leading: Icon(Icons.psychology, size: 14, color: statusColor),
        title: Text(
          loc.researchingLabel,
          style: AppTypography.labelSmall.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        subtitle: Text(
          '${message.toolCalls.length} steps',
          style: AppTypography.labelSmall.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        children: [
          ...message.toolCalls.map((call) {
            final isError = call.resultSummary.startsWith('❌');
            final dot = isError
                ? colors.error
                : Colors.green.withValues(alpha: 0.8);
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              title: Text(
                call.toolName,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              subtitle: Text(
                call.resultSummary,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
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
    // Matches [book_id:para_id:line_id] or [book_id:para_id:line_from-line_to]
    // Range separator: hyphen (-) or en-dash (–, U+2013).
    final citationRegex = RegExp(
      r'\[([a-zA-Z0-9_.-]+):(\d+):(\d+)(?:[-\u2013](\d+))?\]',
    );
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
      final lineIdTo = match.group(4) != null
          ? int.tryParse(match.group(4)!)
          : null;

      final label = lineIdTo != null
          ? '$bookId §$paraId:$lineId-$lineIdTo'
          : '$bookId §$paraId:$lineId';

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _openCitation(
              context,
              ref,
              bookId,
              paraId,
              lineId,
              lineIdTo: lineIdTo,
            ),
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
                    label,
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
    return AiMarkdownView(
      data: text,
      onCitationTap: (bookId, paraId, lineId, {lineIdTo}) => _openCitation(
        context,
        ref,
        bookId,
        paraId,
        lineId,
        lineIdTo: lineIdTo,
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    bool isUser,
    String displayText,
    ColorScheme colors,
  ) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy button (both)
          _ActionChip(
            icon: Icons.content_copy,
            tooltip: loc.copyMessage,
            onTap: () {
              Clipboard.setData(ClipboardData(text: displayText));
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.copied),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  width: 100,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
          // Edit button (user only)
          if (isUser && onEdit != null)
            _ActionChip(
              icon: Icons.edit,
              tooltip: loc.editNote,
              onTap: onEdit!,
            ),
          // Share button (assistant only): export the response as a
          // PDF document and open the system share sheet.
          if (!isUser)
            _ActionChip(
              icon: Icons.share,
              tooltip: loc.share,
              onTap: () {
                AiResponseShareService.shareResponseAsPdf(text: displayText);
              },
            ),
          // Retry button (assistant only)
          if (!isUser && onRetry != null)
            _ActionChip(
              icon: Icons.refresh,
              tooltip: loc.retry,
              onTap: onRetry!,
            ),
        ],
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
    int lineId, {
    int? lineIdTo,
  }) {
    // Release the chat input's focus before opening the reference. On a
    // touch device the input keeps focus (and the keyboard stays up) across
    // the modal quickview, so when the user closes the sheet / goes back the
    // keyboard pops up again over the chat — release it here so the user can
    // read the passage comfortably. On desktop there is no touch keyboard, so
    // keep focus so the user can resume typing right away after going back.
    final isTouch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.fuchsia;
    if (isTouch) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    // Open a quickview preview of the cited passage instead of jumping
    // straight to the reader; the user can open the book from there.
    showCitationQuickview(
      context,
      ref,
      bookId: bookId,
      bookName: bookId,
      paraId: paraId,
      lineId: lineId,
      lineIdTo: lineIdTo,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  COPY BUTTON
// ═══════════════════════════════════════════════════════════════════════════

/// Compact action chip for message action buttons.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(
            icon,
            size: 14,
            color: colors.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

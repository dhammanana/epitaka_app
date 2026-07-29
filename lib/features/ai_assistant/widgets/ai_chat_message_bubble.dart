library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../models/ai_assistant_models.dart';
import '../services/ai_prompt_templates.dart';
import 'ai_source_excerpt_popup.dart';

class AiChatMessageBubble extends ConsumerWidget {
  final AiChatMessage message;
  final String? streamingText;

  const AiChatMessageBubble({
    super.key,
    required this.message,
    this.streamingText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final isPhone = ResponsiveBreakpoint.isPhone(context);

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
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Mode badge on assistant messages
          if (!isUser) _buildModeBadge(colors),
          // Message bubble
          Container(
            padding: EdgeInsets.all(isPhone ? 10 : 14),
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
            child: isUser
                ? _buildUserText(colors)
                : _buildAssistantContent(context, ref, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBadge(ColorScheme colors) {
    final label = message.mode == AiChatMode.literalReview
        ? '\u{1F4D6} Literal Review'
        : '\u{1F4AC} Answer';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: message.mode == AiChatMode.literalReview
                  ? Colors.purple.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: message.mode == AiChatMode.literalReview
                    ? Colors.purple[700]
                    : Colors.blue[700],
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserText(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // User's original message
        Text(
          message.text,
          style: AppTypography.bodyTranslation.copyWith(
            color: colors.onSurface,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        // English translation (if different from original)
        if (message.translation != null && message.translation!.trim().isNotEmpty && message.translation != message.text) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate, size: 12, color: colors.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    message.translation!,
                    style: AppTypography.bodyTranslation.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Answer copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildAssistantContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colors,
  ) {
    final displayText = message.isStreaming && streamingText != null
        ? streamingText!
        : message.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRichText(context, ref, displayText, colors),
        if (message.isStreaming)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (!message.isStreaming && displayText.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildMessageActions(context, colors, displayText),
          if (message.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSourcesBar(context, ref, colors),
          ],
        ],
      ],
    );
  }

  /// Small action buttons row (copy, etc.) shown below each assistant message.
  Widget _buildMessageActions(
    BuildContext context,
    ColorScheme colors,
    String fullText,
  ) {
    return OverflowBar(
      spacing: 4,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => _copyText(context, fullText),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy, size: 13, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(
                  'Copy',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRichText(
    BuildContext context,
    WidgetRef ref,
    String text,
    ColorScheme colors,
  ) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in AiPromptTemplates.sourceRefRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 15,
            height: 1.6,
          ),
        ));
      }

      final sourceNum = match.group(1) ?? '';

      // Render [Source N] as a plain styled TextSpan (no GestureDetector)
      // to avoid any gesture competition with the parent ListView scroll.
      // The source popup is accessible via source chips below the message.
      spans.add(TextSpan(
        text: '[Source $sourceNum]',
        style: TextStyle(
          color: colors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          backgroundColor: colors.primary.withValues(alpha: 0.15),
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 15,
          height: 1.6,
        ),
      ));
    }

    // IgnorePointer + Text.rich — the text renders visually but is
    // completely transparent to pointer events. All gestures (drag to
    // scroll, tap) pass through to the parent ListView.
    // Copy via the "Copy" button below; source popup via chips below.
    // ignoringSemantics: false preserves screen reader accessibility.
    return IgnorePointer(
      ignoring: true,
      ignoringSemantics: false,
      child: Text.rich(
        TextSpan(children: spans),
      ),
    );
  }

  Widget _buildSourcesBar(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link, size: 12, color: colors.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              'Sources (${message.sources.length})',
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
          children: message.sources.map((source) {
            final index = message.sources.indexOf(source) + 1;
            return ActionChip(
              label: Text(
                '#$index ${source.bookName ?? source.bookId} \u00A7${source.paraId}',
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              avatar: Icon(
                Icons.auto_stories,
                size: 12,
                color: colors.primary,
              ),
              onPressed: () => showSourceExcerptPopup(context, source),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              side: BorderSide.none,
              backgroundColor: colors.primaryContainer.withValues(alpha: 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }
}

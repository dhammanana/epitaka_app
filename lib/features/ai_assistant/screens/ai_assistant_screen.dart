library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../models/ai_assistant_models.dart';
import '../providers/ai_chat_provider.dart';
import '../providers/ai_settings_provider.dart';
import '../widgets/ai_chat_message_bubble.dart';
import '../widgets/ai_settings_sheet.dart';

const _featureName = 'Paññā';
const _featureSubtitle = 'AI Research Assistant';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(aiSettingsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);
    final settings = ref.watch(aiSettingsProvider);
    final colors = Theme.of(context).colorScheme;

    ref.listen(aiChatProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0) ||
          next.isLoading != (prev?.isLoading ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        toolbarHeight: AppDimensions.appBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Icon(Icons.auto_awesome, color: Colors.transparent),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primary.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _featureName,
                  style: AppTypography.headlineLarge.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  _featureSubtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune,
              color: settings.isValid ? colors.onSurfaceVariant : Colors.orange,
              size: 20,
            ),
            tooltip: 'AI Settings',
            onPressed: () => showAiSettingsSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildModeSelector(state, colors),
          if (state.error != null) _buildErrorBanner(state.error!, colors),
          Expanded(
            child: state.messages.isEmpty
                ? _buildEmptyState(context, state, settings, colors)
                : _buildMessageList(state, colors),
          ),
          _buildInputBar(state, colors),
        ],
      ),
    );
  }

  Widget _buildModeSelector(AiChatState state, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile, AppDimensions.sm,
        AppDimensions.marginMobile, AppDimensions.xs,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeOption(
              label: '\u{1F4AC} Answer',
              subtitle: 'Q&A',
              selected: state.mode == AiChatMode.answerQuestion,
              colors: colors,
              onTap: () => ref.read(aiChatProvider.notifier).setMode(AiChatMode.answerQuestion),
            ),
          ),
          Expanded(
            child: _ModeOption(
              label: '\u{1F4D6} Literal Review',
              subtitle: 'Deep research',
              selected: state.mode == AiChatMode.literalReview,
              colors: colors,
              onTap: () => ref.read(aiChatProvider.notifier).setMode(AiChatMode.literalReview),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.marginMobile),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onErrorContainer, fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: () => ref.read(aiChatProvider.notifier).clearError(),
            icon: Icon(Icons.close, size: 14, color: colors.onErrorContainer),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, AiChatState state,
    AiAssistantSettings settings, ColorScheme colors,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  colors.primary.withValues(alpha: 0.15),
                  colors.primary.withValues(alpha: 0.05),
                ]),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(Icons.auto_awesome, size: 32,
                  color: colors.primary.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),
            Text(
              state.mode == AiChatMode.literalReview ? 'Literal Review' : 'Ask a Question',
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface, fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              state.mode == AiChatMode.literalReview
                  ? 'Enter a research topic to search the Tipitaka and receive a structured literal review with Pāli quotes and citations.'
                  : 'Ask any question about the Tipitaka. The Assistant will search the Pāli Canon and provide a grounded answer with sources.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant, height: 1.5, fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            if (!settings.isValid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text('API key required',
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.orange[700], fontWeight: FontWeight.w600,
                      )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => showAiSettingsSheet(context),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Configure API Key'),
              ),
            ],
            if (settings.isValid && state.messages.isEmpty)
              FilledButton.tonalIcon(
                onPressed: () => _focusNode.requestFocus(),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Start a conversation'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(AiChatState state, ColorScheme colors) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        // Pass streaming text to the last message if it's being streamed
        final isLast = index == state.messages.length - 1;
        final streamingText = (isLast && state.isStreaming)
            ? state.streamingText
            : null;

        if (index > 0) {
          final prev = state.messages[index - 1];
          final gap = message.timestamp.difference(prev.timestamp);
          if (gap.inMinutes >= 5) {
            return Column(children: [
              _buildTimestampDivider(message.timestamp, colors),
              AiChatMessageBubble(
                message: message,
                streamingText: streamingText,
              ),
            ]);
          }
        }
        return AiChatMessageBubble(
          message: message,
          streamingText: streamingText,
        );
      },
    );
  }

  Widget _buildTimestampDivider(DateTime timestamp, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant, fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(AiChatState state, ColorScheme colors) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.marginMobile, AppDimensions.sm,
        AppDimensions.marginMobile, MediaQuery.of(context).padding.bottom + AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (state.isLoading || state.isStreaming) ? null : (_) => _sendMessage(),
              style: TextStyle(color: colors.onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: state.mode == AiChatMode.literalReview
                    ? 'Enter a research topic\u2026'
                    : 'Ask a question about the Tipitaka\u2026',
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 15,
                ),
                filled: true,
                fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: state.isLoading
                ? colors.onSurfaceVariant.withValues(alpha: 0.2)
                : colors.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: (state.isLoading || state.isStreaming) ? null : _sendMessage,
              child: Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                child: state.isLoading
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.onSurfaceVariant,
                        ),
                      )
                    : Icon(Icons.arrow_upward, color: colors.surface, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _ModeOption({
    required this.label, required this.subtitle,
    required this.selected, required this.colors, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          boxShadow: selected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4, offset: const Offset(0, 1),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTypography.labelMedium.copyWith(
              color: selected ? colors.primary : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            )),
            Text(subtitle, style: AppTypography.labelSmall.copyWith(
              color: selected
                  ? colors.primary.withValues(alpha: 0.7)
                  : colors.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 9,
            )),
          ],
        ),
      ),
    );
  }
}

/// Vimaṃsa (विमंसा) — Investigation & Exploration screen.
///
/// A tool-based AI research assistant for the Tipitaka with persistent
/// chat threads, conversation history, per-thread message limits, and
/// the @ mention system for attaching headings as context.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../core/utils/velthuis.dart';
import '../../gavesana/screens/gavesana_drawer.dart';
import '../models/ai_qa_models.dart';
import '../models/heading_attachment.dart';
import '../providers/ai_qa_provider.dart';
import '../providers/ai_qa_settings_provider.dart';
import '../providers/chat_history_provider.dart';
import '../providers/mention_provider.dart';
import '../services/mention_service.dart';
import '../widgets/ai_qa_chat_bubble.dart';
import '../widgets/ai_qa_settings_sheet.dart';
import '../widgets/attachment_bar.dart';
import '../widgets/mention_index_build_dialog.dart';
import '../widgets/mention_overlay.dart';

const _featureName = 'Vimaṃsa';

class VimamsaScreen extends ConsumerStatefulWidget {
  final String? initialThreadId;

  /// When true, renders as a compact dockable panel (desktop docking tab)
  /// instead of a full screen: no Scaffold/AppBar/drawer, just a slim
  /// header row + the chat body. Reuses the exact same chat state/logic.
  final bool panelMode;

  const VimamsaScreen({super.key, this.initialThreadId, this.panelMode = false});

  @override
  ConsumerState<VimamsaScreen> createState() => _VimamsaScreenState();
}

class _VimamsaScreenState extends ConsumerState<VimamsaScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mentionLayerLink = LayerLink();

  /// Attached to the newest assistant message so the screen can scroll the
  /// start of a freshly-rendered response into view once streaming finishes.
  final GlobalKey _latestResponseKey = GlobalKey();

  /// Whether the mention overlay is currently showing.
  bool _mentionActive = false;

  /// Prevents re-entry while the controller text is being updated after
  /// Velthuis conversion (the value setter notifies listeners synchronously).
  bool _isConverting = false;

  /// Whether we have checked the mention index status at least once.
  bool _mentionIndexChecked = false;

  /// True while a mention index build is in progress.
  bool _mentionIndexBuilding = false;

  @override
  void initState() {
    super.initState();
    // Add listener for @ mention detection
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);

    Future.microtask(() {
      ref.read(aiQaSettingsProvider.notifier).load();

      // Check for a staged initial prompt (from reader context menu).
      // Send it automatically and clear the staged prompt.
      final initialPrompt = ref.read(aiQaInitialPromptProvider);
      if (initialPrompt != null && initialPrompt.isNotEmpty) {
        ref.read(aiQaInitialPromptProvider.notifier).state = null;
        ref.read(aiQaProvider.notifier).sendMessage(initialPrompt);
      } else if (widget.initialThreadId != null) {
        ref.read(aiQaProvider.notifier).loadThread(widget.initialThreadId!);
      }

      // Check mention index status once on init
      _checkMentionIndex();
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Prevent re-entry when updating the controller text after conversion.
    if (_isConverting) return;

    // Apply Velthuis conversion on-the-fly so users can type Velthuis
    // notation (dhamma.m → dhammaṃ) or any Pāli script — same behavior
    // as the search boxes. The converted text is what the mention search
    // (and, later, the AI prompt) sees.
    final raw = _textController.text;
    final converted = velthuis(raw);
    if (converted != raw) {
      _isConverting = true;
      _textController.value = convertedTextEditingValue(_textController.value);
      _isConverting = false;
    }

    // Read the post-conversion text: when a conversion happened the setter
    // above already replaced the controller with `converted`; reading it
    // back (instead of reusing the local) keeps the mention search in sync
    // even if the two conversion helpers ever diverge.
    final text = _textController.text;
    ref.read(mentionSearchProvider.notifier).onTextChanged(text);

    final isActive = ref.read(mentionSearchProvider).isActive;
    if (isActive != _mentionActive) {
      setState(() {
        _mentionActive = isActive;
      });
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _mentionActive) {
      ref.read(mentionSearchProvider.notifier).deactivate();
      setState(() => _mentionActive = false);
    }
  }

  Future<void> _checkMentionIndex() async {
    await ref.read(isMentionIndexReadyProvider.future);
    if (mounted) {
      setState(() => _mentionIndexChecked = true);
    }
  }

  Future<void> _buildMentionIndex() async {
    setState(() => _mentionIndexBuilding = true);
    try {
      if (!mounted) return;
      final count = await showMentionIndexBuildDialog(context);
      debugPrint('[VIMAṂSA] Mention index built: $count entries');
      // Invalidate the cached FutureProvider so the banner re-checks.
      ref.invalidate(isMentionIndexReadyProvider);
      await _checkMentionIndex();
    } catch (e) {
      debugPrint('[VIMAṂSA] Failed to build mention index: $e');
    } finally {
      if (mounted) {
        setState(() => _mentionIndexBuilding = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    // Convert one more time for safety (idempotent — the on-the-fly
    // conversion in _onTextChanged already keeps the field converted).
    final text = velthuis(_textController.text).trim();
    if (text.isEmpty) return;

    // Collect attachments and clear input immediately
    var attachments = ref.read(attachmentsProvider);
    _textController.clear();
    ref.read(attachmentsProvider.notifier).clear();
    setState(() => _mentionActive = false);

    if (attachments.isNotEmpty) {
      // Fetch Pāli text for book-level attachments (async, done before send)
      final service = ref.read(mentionServiceProvider);
      final enriched = await Future.wait(
        attachments.map((a) async {
          if (a.entryType == AttachmentEntryType.book && a.fullText == null) {
            final paliText = await service.fetchPaliText(a.bookId);
            return HeadingAttachment.create(
              bookId: a.bookId,
              paraId: a.paraId,
              title: a.title,
              bookName: a.bookName,
              entryType: a.entryType,
              hierarchy: a.hierarchy,
              chapterLen: a.chapterLen,
              mulaRef: a.mulaRef,
              atthaRef: a.atthaRef,
              tikaRef: a.tikaRef,
              fullText: paliText,
            );
          }
          return a;
        }),
      );

      ref
          .read(aiQaProvider.notifier)
          .sendMessageWithAttachments(text, enriched);
    } else {
      ref.read(aiQaProvider.notifier).sendMessage(text);
    }

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    try {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {}
  }

  /// Bring the top of the newest assistant message (the just-finished
  /// response) to the top of the viewport. Retries briefly until the message
  /// has rendered and its key is attached.
  void _scrollToResponseStart({int retries = 0}) {
    final ctx = _latestResponseKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      if (retries < 5) {
        Future.delayed(const Duration(milliseconds: 80), () {
          if (!mounted) return;
          _scrollToResponseStart(retries: retries + 1);
        });
      }
      return;
    }
    try {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ThreadHistorySheet(),
    );
  }

  void _startNewChat() async {
    await ref.read(aiQaProvider.notifier).startNewThread();
    _focusNode.requestFocus();
  }

  /// Handle keyboard events for the mention overlay.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_mentionActive) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final notifier = ref.read(mentionSearchProvider.notifier);

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        notifier.moveSelection(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        notifier.moveSelection(-1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        final selected = notifier.selectedResult;
        if (selected != null) {
          final attachmentsNotifier = ref.read(attachmentsProvider.notifier);
          attachmentsNotifier.add(selected.toAttachment());
          notifier.deactivate();
          setState(() => _mentionActive = false);
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        notifier.deactivate();
        setState(() => _mentionActive = false);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiQaProvider.select((s) => s.messages));
    final isLoading = ref.watch(aiQaProvider.select((s) => s.isLoading));
    final error = ref.watch(aiQaProvider.select((s) => s.error));
    final settings = ref.watch(aiQaSettingsProvider);
    final currentThreadTitle = ref.watch(currentThreadTitleProvider);
    final currentThreadId = ref.watch(currentThreadIdProvider);
    final colors = Theme.of(context).colorScheme;
    final attachments = ref.watch(attachmentsProvider);

    ref.listen(aiQaProvider, (prev, next) {
      // A streamed response just finished rendering — jump to the START of
      // the response so the user reads from the beginning. Staying pinned at
      // the end of a long answer was annoying.
      final hadStreaming = (prev?.messages ?? []).any((m) => m.isStreaming);
      final hasStreaming = next.messages.any((m) => m.isStreaming);
      if (hadStreaming &&
          !hasStreaming &&
          next.messages.isNotEmpty &&
          !next.messages.last.isUser) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToResponseStart(),
        );
        return;
      }
      if (next.messages.length > (prev?.messages.length ?? 0) ||
          next.isLoading != (prev?.isLoading ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final body = _buildChatBody(
      colors: colors,
      messages: messages,
      isLoading: isLoading,
      error: error,
      settings: settings,
      currentThreadId: currentThreadId,
      attachments: attachments,
    );

    if (widget.panelMode) {
      // Compact dockable panel: slim header + chat body (no Scaffold).
      return Column(
        children: [
          _buildPanelHeader(
            colors: colors,
            currentThreadTitle: currentThreadTitle,
            messages: messages,
            settings: settings,
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const MainDrawer(),
      backgroundColor: colors.surface,
      appBar: AppBar(
        toolbarHeight: AppDimensions.appBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: colors.onSurfaceVariant),
          tooltip: AppLocalizations.of(context).navigationMenu,
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
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
                    currentThreadTitle.isNotEmpty
                        ? currentThreadTitle
                        : AppLocalizations.of(context).investigationExploration,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // History button
          IconButton(
            icon: Icon(Icons.history, size: 20, color: colors.onSurfaceVariant),
            tooltip: AppLocalizations.of(context).chatHistory,
            onPressed: _showHistorySheet,
          ),
          // New chat button
          IconButton(
            icon: Icon(
              Icons.add_comment_outlined,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            tooltip: AppLocalizations.of(context).newChat,
            onPressed: _startNewChat,
          ),
          if (messages.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
              tooltip: AppLocalizations.of(context).clearChat,
              onPressed: () {
                ref.read(aiQaProvider.notifier).clearChat();
              },
            ),
          IconButton(
            icon: Icon(
              Icons.tune,
              color: settings.isValid ? colors.onSurfaceVariant : Colors.orange,
              size: 20,
            ),
            tooltip: AppLocalizations.of(context).vimamsaSettings,
            onPressed: () => showAiQaSettingsSheet(context),
          ),
        ],
      ),
      body: body,
    );
  } // ── Build helpers ─────────────────────────────────────────────────────

  /// Shared chat body (messages + banners + input + @ mention overlay).
  /// Used by both the full-screen Scaffold and the compact panel mode.
  Widget _buildChatBody({
    required ColorScheme colors,
    required List<AiQaMessage> messages,
    required bool isLoading,
    required String? error,
    required AiQaSettings settings,
    required String? currentThreadId,
    required List<HeadingAttachment> attachments,
  }) {
    return Stack(
      children: [
        // Main content column (messages + attachment bar + input)
        Column(
          children: [
            if (error != null) _buildErrorBanner(error, colors),
            _buildMentionIndexBanner(colors),
            if (currentThreadId != null && messages.isNotEmpty)
              _buildThreadIndicator(currentThreadId, colors),
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState(context, isLoading, settings, colors)
                  : AiQaMessageListView(
                      scrollController: _scrollController,
                      messages: messages,
                      latestResponseKey: _latestResponseKey,
                    ),
            ),

            // ── Answer mode (orthodox / knowledge) ────────────────────
            _AnswerModeToggle(colors: colors),

            // ── Attachment chips bar ──────────────────────────────────
            if (attachments.isNotEmpty) const AttachmentBar(),

            // ── Input bar ─────────────────────────────────────────────
            _AiQaInputBar(
              isLoading: isLoading,
              textController: _textController,
              focusNode: _focusNode,
              onSend: _sendMessage,
              layerLink: _mentionLayerLink,
              onKeyEvent: _handleKeyEvent,
            ),
          ],
        ),

        // ── @ Mention Overlay (floats above input bar, positioned via LayerLink) ─
        if (_mentionActive)
          CompositedTransformFollower(
            link: _mentionLayerLink,
            offset: const Offset(0, -8),
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            child: const MentionOverlay(),
          ),
      ],
    );
  }

  /// Compact header for the dockable panel mode.
  Widget _buildPanelHeader({
    required ColorScheme colors,
    required String currentThreadTitle,
    required List<AiQaMessage> messages,
    required AiQaSettings settings,
  }) {
    return Container(
      height: AppDimensions.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      color: colors.surface,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.primary.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _featureName,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currentThreadTitle.isNotEmpty
                      ? currentThreadTitle
                      : AppLocalizations.of(context).investigationExploration,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.history, size: 18, color: colors.onSurfaceVariant),
            tooltip: AppLocalizations.of(context).chatHistory,
            visualDensity: VisualDensity.compact,
            onPressed: _showHistorySheet,
          ),
          IconButton(
            icon: Icon(
              Icons.add_comment_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            tooltip: AppLocalizations.of(context).newChat,
            visualDensity: VisualDensity.compact,
            onPressed: _startNewChat,
          ),
          if (messages.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              tooltip: AppLocalizations.of(context).clearChat,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                ref.read(aiQaProvider.notifier).clearChat();
              },
            ),
          IconButton(
            icon: Icon(
              Icons.tune,
              color: settings.isValid ? colors.onSurfaceVariant : Colors.orange,
              size: 18,
            ),
            tooltip: AppLocalizations.of(context).vimamsaSettings,
            visualDensity: VisualDensity.compact,
            onPressed: () => showAiQaSettingsSheet(context),
          ),
        ],
      ),
    );
  }

  /// Show a subtle banner if the heading index is not yet built.
  Widget _buildMentionIndexBanner(ColorScheme colors) {
    // Don't show until the initial check has completed.
    if (!_mentionIndexChecked) return const SizedBox.shrink();

    final mentionIndexAsync = ref.watch(isMentionIndexReadyProvider);
    final notBuilt = mentionIndexAsync.when(
      data: (ready) => !ready,
      loading: () => false,
      error: (_, __) => true,
    );
    if (!notBuilt) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
        vertical: 4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            _mentionIndexBuilding
                ? Icons.build_circle
                : Icons.bookmark_add_outlined,
            size: 14,
            color: colors.tertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _mentionIndexBuilding
                  ? AppLocalizations.of(context).buildingHeadingIndex
                  : AppLocalizations.of(context).headingIndexNeeded,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onTertiaryContainer,
                fontSize: 11,
              ),
            ),
          ),
          if (_mentionIndexBuilding)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.tertiary,
              ),
            )
          else
            SizedBox(
              height: 24,
              child: TextButton.icon(
                onPressed: _buildMentionIndex,
                icon: const Icon(Icons.build, size: 12),
                label: Text(
                  AppLocalizations.of(context).buildShort,
                  style: const TextStyle(fontSize: 10),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThreadIndicator(String threadId, ColorScheme colors) {
    final threadAsync = ref.watch(chatThreadProvider(threadId));
    return threadAsync.when(
      data: (thread) {
        if (thread == null) return const SizedBox.shrink();
        final remaining = thread.maxMessages - thread.messageCount;
        if (remaining <= 0) return const SizedBox.shrink();
        if (remaining <= 2) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Colors.orange.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).queriesRemainingInThread(remaining),
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.orange[700],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildErrorBanner(String error, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
      ),
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
                color: colors.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: () => ref.read(aiQaProvider.notifier).clearError(),
            icon: Icon(Icons.close, size: 14, color: colors.onErrorContainer),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isLoading,
    AiQaSettings settings,
    ColorScheme colors,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.15),
                      colors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 32,
                  color: colors.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Vīmaṃsāya puccha',
                style: AppTypography.headlineSmall.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).askAboutTipitakaShort,
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).vimamsaIntro,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 8),
              _buildExamplePrompt(
                colors,
                'What are the commentaries on the Satipaṭṭhāna Sutta?',
              ),
              const SizedBox(height: 8),
              _buildExamplePrompt(
                colors,
                'Compare the treatment of mettā in different nikāyas',
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
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).apiKeyRequired,
                        style: AppTypography.labelMedium.copyWith(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => showAiQaSettingsSheet(context),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(AppLocalizations.of(context).configureApiKey),
                ),
              ],
              if (settings.isValid && !isLoading)
                FilledButton.tonalIcon(
                  onPressed: () => _focusNode.requestFocus(),
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(AppLocalizations.of(context).startAsking),
                ),

              // History quick access
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: _showHistorySheet,
                icon: Icon(Icons.history, size: 16, color: colors.primary),
                label: Text(
                  AppLocalizations.of(context).viewPastConversations,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamplePrompt(ColorScheme colors, String prompt) {
    return InkWell(
      onTap: () {
        _textController.text = prompt;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_right, size: 18, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                prompt,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  THREAD HISTORY BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _ThreadHistorySheet extends ConsumerWidget {
  const _ThreadHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final threadsAsync = ref.watch(chatThreadsProvider);

    return DraggableScrollableSheet(
      // Don't fill the whole screen (see dictionary_sheet.dart): with the
      // default `expand: true` the sheet's scrollable covers the full
      // screen and swallows taps above the sheet, so tapping outside can
      // no longer dismiss the modal. `expand: false` keeps the top space
      // as the dismissible modal barrier.
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusSheet),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                  vertical: AppDimensions.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).chatHistoryTitle,
                      style: AppTypography.headlineSmall.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(aiQaProvider.notifier).startNewThread();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        AppLocalizations.of(context).newChatTitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Thread list
              Expanded(
                child: threadsAsync.when(
                  data: (threads) {
                    if (threads.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context).noConversationsYet,
                                style: AppTypography.labelMedium.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context).startNewChatToBegin,
                                style: AppTypography.labelSmall.copyWith(
                                  color: colors.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: threads.length,
                      itemBuilder: (context, index) {
                        final thread = threads[index];
                        return _ThreadHistoryTile(thread: thread);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(AppLocalizations.of(context).errorMessage(e.toString())),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreadHistoryTile extends ConsumerWidget {
  final ChatThread thread;

  const _ThreadHistoryTile({required this.thread});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final currentId = ref.watch(currentThreadIdProvider);

    final isActive = thread.id == currentId;

    return ListTile(
      selected: isActive,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.15),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? colors.primary.withValues(alpha: 0.1)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isActive ? Icons.chat : Icons.chat_bubble_outline,
          size: 16,
          color: isActive ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
      title: Text(
        thread.title,
        style: AppTypography.labelMedium.copyWith(
          color: colors.onSurface,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            _formatDate(context, thread.updatedAt),
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${thread.messageCount}/${thread.maxMessages}',
            style: AppTypography.labelSmall.copyWith(
              color: thread.isFull
                  ? Colors.orange
                  : colors.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: thread.isFull ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (thread.isFull) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.lock_outline,
              size: 10,
              color: Colors.orange.withValues(alpha: 0.6),
            ),
          ],
        ],
      ),
      trailing: isActive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppLocalizations.of(context).activeLabel,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(AppLocalizations.of(context).deleteConversation),
                      content: Text(
                        AppLocalizations.of(context).deleteThreadConfirm(thread.title),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(AppLocalizations.of(context).cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(
                            AppLocalizations.of(context).delete,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref
                        .read(chatHistoryNotifierProvider)
                        .deleteThread(thread.id);
                  }
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, size: 16),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).delete),
                    ],
                  ),
                ),
              ],
            ),
      onTap: () {
        Navigator.of(context).pop();
        if (!isActive) {
          ref.read(aiQaProvider.notifier).loadThread(thread.id);
        }
      },
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return AppLocalizations.of(context).justNow;
    }
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MESSAGE LIST VIEW
// ═══════════════════════════════════════════════════════════════════════════

class AiQaMessageListView extends ConsumerWidget {
  final ScrollController scrollController;
  final List<AiQaMessage> messages;

  /// Attached to the newest assistant message so the screen can scroll the
  /// response's start into view once streaming finishes.
  final GlobalKey? latestResponseKey;

  const AiQaMessageListView({
    super.key,
    required this.scrollController,
    required this.messages,
    this.latestResponseKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Index of the newest assistant (non-user, non-placeholder) message.
    int? latestResponseIndex;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].isUser && messages[i].id != 'thinking') {
        latestResponseIndex = i;
        break;
      }
    }

    final listContent = ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final bubble = AiQaMessageBubble(
          key: ValueKey(message.id),
          message: message,
        );
        final child = index == latestResponseIndex && latestResponseKey != null
            ? KeyedSubtree(key: latestResponseKey, child: bubble)
            : bubble;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: child,
        );
      },
    );

    // On desktop, center the chat in a narrower column for readability.
    final isDesktop = ResponsiveBreakpoint.isDesktop(context);
    if (isDesktop) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: listContent,
        ),
      );
    }
    return listContent;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ANSWER MODE TOGGLE
// ═══════════════════════════════════════════════════════════════════════════

/// Compact toggle for the answer mode.
///
/// Orthodox (default, ticked): answers are based ONLY on the passages found
/// in the Tipitaka.  Unticking allows the AI to also use its own knowledge.
class _AnswerModeToggle extends ConsumerWidget {
  final ColorScheme colors;

  const _AnswerModeToggle({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiQaSettingsProvider);

    void toggle() {
      ref
          .read(aiQaSettingsProvider.notifier)
          .setOrthodoxMode(!settings.orthodoxMode);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        0,
        AppDimensions.marginMobile,
        2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Checkbox(
              value: settings.orthodoxMode,
              onChanged: (v) {
                ref
                    .read(aiQaSettingsProvider.notifier)
                    .setOrthodoxMode(v ?? true);
              },
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: GestureDetector(
              onTap: toggle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).orthodox,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    settings.orthodoxMode
                        ? AppLocalizations.of(context).orthodoxDesc
                        : AppLocalizations.of(context).unorthodoxDesc,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  INPUT BAR (with @ mention support)
// ═══════════════════════════════════════════════════════════════════════════

/// Keyboard event handler type.
typedef KeyEventHandler = KeyEventResult Function(FocusNode, KeyEvent);

class _AiQaInputBar extends ConsumerWidget {
  final bool isLoading;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final LayerLink layerLink;
  final KeyEventHandler onKeyEvent;

  const _AiQaInputBar({
    required this.isLoading,
    required this.textController,
    required this.focusNode,
    required this.onSend,
    required this.layerLink,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final mentionState = ref.watch(mentionSearchProvider);
    final currentThread = ref.watch(currentThreadIdProvider);

    // Check if the thread is full using when()
    final isThreadFull = currentThread != null
        ? ref
              .watch(chatThreadProvider(currentThread))
              .when(
                data: (thread) => thread?.isFull ?? false,
                loading: () => false,
                error: (_, __) => false,
              )
        : false;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        MediaQuery.of(context).padding.bottom + AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Tip: @ to attach
          if (!mentionState.isActive)
            Tooltip(
              message: AppLocalizations.of(context).typeAtToAttach,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 4),
                child: Icon(
                  Icons.bookmark_add_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ),

          Expanded(
            child: CompositedTransformTarget(
              link: layerLink,
              child: Focus(
                onKeyEvent: (node, event) => onKeyEvent(focusNode, event),
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (isLoading || isThreadFull)
                      ? null
                      : (_) => onSend(),
                  style: TextStyle(color: colors.onSurface, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: isThreadFull
                        ? AppLocalizations.of(context).threadIsFull
                        : AppLocalizations.of(context).askTipitakaOrAttach,
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: (isLoading || isThreadFull)
                ? colors.onSurfaceVariant.withValues(alpha: 0.2)
                : colors.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: (isLoading || isThreadFull) ? null : onSend,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : Icon(
                        isThreadFull ? Icons.lock : Icons.arrow_upward,
                        color: isThreadFull
                            ? colors.onSurfaceVariant.withValues(alpha: 0.4)
                            : colors.surface,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

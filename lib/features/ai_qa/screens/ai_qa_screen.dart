/// Vīmaṃsā (विमंसा) — Investigation & Exploration screen.
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
import '../../../core/utils/velthuis.dart';
import '../../gavesana/screens/gavesana_drawer.dart';
import '../../shared/services/ai_model_service.dart';
import '../../shared/widgets/ai_error_card.dart';
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

const _featureName = 'Vīmaṃsā';

class VimamsaScreen extends ConsumerStatefulWidget {
  final String? initialThreadId;

  /// When true, renders as a compact dockable panel (desktop docking tab)
  /// instead of a full screen: no Scaffold/AppBar/drawer, just a slim
  /// header row + the chat body. Reuses the exact same chat state/logic.
  final bool panelMode;

  /// Hides the slim panel header (used by the reader AI sheet, which shows
  /// its own chapter row instead). Only applies with [panelMode].
  final bool hidePanelHeader;

  /// Quick-ask buttons shown centered in the empty state (used by the
  /// reader AI sheet: Summarize / Explain / Grammar / Mindmap). Tapping one
  /// sends its prompt with the current attachments. Null keeps the default
  /// empty state (logo + history).
  final List<VimamsaQuickAction>? quickActions;

  const VimamsaScreen({
    super.key,
    this.initialThreadId,
    this.panelMode = false,
    this.hidePanelHeader = false,
    this.quickActions,
  });

  @override
  ConsumerState<VimamsaScreen> createState() => _VimamsaScreenState();
}

/// One centered quick-ask button in the empty chat state.
class VimamsaQuickAction {
  final IconData icon;
  final String label;
  final String prompt;

  const VimamsaQuickAction({
    required this.icon,
    required this.label,
    required this.prompt,
  });
}

class _VimamsaScreenState extends ConsumerState<VimamsaScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _chatFocusNode = FocusNode();
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
    _chatFocusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Prevent re-entry when updating the controller text after conversion.
    if (_isConverting) return;

    // Apply Velthuis conversion on-the-fly so users can type Velthuis
    // notation (dhamma.m → dhammaṃ). For non-Roman scripts (Sinhala,
    // Thai, Myanmar, …) leave the controller untouched so the user
    // keeps seeing their native script; the mention search still receives
    // the Roman-converted result below.
    final raw = _textController.text;
    final converted = velthuis(raw);
    if (isRomanScript(raw) && converted != raw) {
      _isConverting = true;
      _textController.value = convertedTextEditingValue(_textController.value);
      _isConverting = false;
    }

    // Read the post-conversion text. For non-Roman scripts the field still
    // shows the original script, so convert to Roman here — the mention
    // index is stored in IAST — before the mention search sees it.
    final text = velthuis(_textController.text);
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

  /// Remove the consumed `@query` token (e.g. "@test") from the input field
  /// after a mention item was attached, so the user doesn't have to delete
  /// it by hand. Keeps the caret where the token was.
  void _stripMentionToken(String token) {
    final text = _textController.text;
    final idx = text.lastIndexOf(token);
    if (idx < 0) return;
    var next = text.substring(0, idx) + text.substring(idx + token.length);
    // "@test hello" → "hello" (no leading-space artifact); "a @test b" →
    // "a b" (no double space).
    if (idx == 0) {
      next = next.replaceFirst(RegExp(r'^ +'), '');
    } else {
      next = next.replaceAll(RegExp(r' {2,}'), ' ');
    }
    // Guarded: don't re-trigger the mention search for this edit.
    _isConverting = true;
    _textController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: idx.clamp(0, next.length)),
      composing: TextRange.empty,
    );
    _isConverting = false;
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
      debugPrint('[Vīmaṃsā] Mention index built: $count entries');
      // Invalidate the cached FutureProvider so the banner re-checks.
      ref.invalidate(isMentionIndexReadyProvider);
      await _checkMentionIndex();
    } catch (e) {
      debugPrint('[Vīmaṃsā] Failed to build mention index: $e');
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

  KeyEventResult _handleChatNavigationKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_focusNode.hasFocus || _mentionActive) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.arrowDown) {
      _scrollController.animateTo(
        (_scrollController.offset + 160).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.arrowUp) {
      _scrollController.animateTo(
        (_scrollController.offset - 160).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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

  void _confirmDeleteThread() {
    final currentThreadId = ref.read(currentThreadIdProvider);
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.deleteConversation),
        content: Text(loc.deleteThreadConfirm(loc.chatHistory)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (currentThreadId != null) {
                ref
                    .read(chatHistoryNotifierProvider)
                    .deleteThread(currentThreadId);
                ref.read(aiQaProvider.notifier).clearChat();
              }
            },
            child: Text(
              loc.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showInThreadSearch() {
    final colors = Theme.of(context).colorScheme;
    final messages = ref.read(aiQaProvider).messages;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _InThreadSearchSheet(messages: messages, colors: colors),
    );
  }

  void _startNewChat() async {
    await ref.read(aiQaProvider.notifier).startNewThread();
    _focusNode.requestFocus();
  }

  /// Send a quick-action prompt (empty-state buttons). Goes through the
  /// same [_sendMessage] path so current attachments travel along.
  void _runQuickAction(String prompt) {
    if (ref.read(aiQaProvider).isLoading) return;
    _textController.text = prompt;
    _sendMessage();
  }

  /// Edit a past user prompt: show an edit dialog, then truncate that
  /// prompt and every later prompt/response and resend the corrected
  /// text as a fresh response.
  Future<void> _showEditDialog(AiQaMessage message) async {
    if (ref.read(aiQaProvider).isLoading) return;
    final controller = TextEditingController(text: message.text);
    final loc = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.editNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(loc.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || result == message.text) return;
    await ref.read(aiQaProvider.notifier).editUserMessage(message.id, result);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
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
        final attached = notifier.attachSelected(
          ref.read(attachmentsProvider.notifier),
        );
        if (attached != null) return KeyEventResult.handled;
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

    // Watch current thread for pinned state
    final isPinned = currentThreadId != null
        ? ref
              .watch(chatThreadProvider(currentThreadId))
              .when(
                data: (t) => t?.isPinned ?? false,
                loading: () => false,
                error: (_, __) => false,
              )
        : false;

    ref.listen<int>(mentionSearchProvider.select((s) => s.stripEpoch), (
      prev,
      next,
    ) {
      if (next == 0) return;
      // A mention item was just attached (tap or enter/tab): strip the
      // consumed "@query" token from the input and hide the overlay.
      final token = ref.read(mentionSearchProvider).stripToken;
      if (token != null && token.isNotEmpty && mounted) {
        _stripMentionToken(token);
      }
      if (_mentionActive && mounted) {
        setState(() => _mentionActive = false);
      }
    });

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
      // [hidePanelHeader] (reader AI sheet) replaces the header with its
      // own chapter row, so skip it here.
      return Column(
        children: [
          if (!widget.hidePanelHeader) ...[
            _buildPanelHeader(
              colors: colors,
              currentThreadTitle: currentThreadTitle,
              messages: messages,
              settings: settings,
            ),
            const Divider(height: 1),
          ],
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
        title: Text(
          _featureName,
          style: AppTypography.headlineLarge.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          // New chat button
          IconButton(
            icon: Icon(Icons.add, size: 22, color: colors.onSurfaceVariant),
            tooltip: AppLocalizations.of(context).newChat,
            onPressed: _startNewChat,
          ),
          // Overflow menu: history, settings, clear
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            onSelected: (value) {
              switch (value) {
                case 'history':
                  _showHistorySheet();
                  break;
                case 'pin':
                  if (currentThreadId != null) {
                    ref
                        .read(chatHistoryNotifierProvider)
                        .toggleThreadPinned(currentThreadId);
                  }
                  break;
                case 'search':
                  _showInThreadSearch();
                  break;
                case 'settings':
                  showAiQaSettingsSheet(context);
                  break;
                case 'delete':
                  _confirmDeleteThread();
                  break;
                case 'clear':
                  ref.read(aiQaProvider.notifier).clearChat();
                  break;
              }
            },
            itemBuilder: (ctx) {
              final loc = AppLocalizations.of(context);
              final fs = settings.chatFontSize;
              final fsLabel = '${(fs * 100).round()}%';
              return [
                PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Text(loc.chatHistory),
                    ],
                  ),
                ),
                if (currentThreadId != null)
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 18,
                          color: isPinned
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(isPinned ? loc.unpinThread : loc.pinThread),
                      ],
                    ),
                  ),
                if (messages.isNotEmpty)
                  PopupMenuItem(
                    value: 'search',
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(loc.searchInThread),
                      ],
                    ),
                  ),
                // ── Font size inline control ──
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(
                        Icons.text_fields,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        loc.fontSize,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const Spacer(),
                      // Decrease button
                      GestureDetector(
                        onTap: fs > 0.7
                            ? () {
                                ref
                                    .read(aiQaSettingsProvider.notifier)
                                    .setChatFontSize(
                                      (fs - 0.1).clamp(0.7, 2.0),
                                    );
                              }
                            : null,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: fs > 0.7
                                ? colors.surfaceContainerHighest
                                : colors.surfaceContainerHighest.withValues(
                                    alpha: 0.3,
                                  ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: fs > 0.7
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fsLabel,
                        style: AppTypography.labelMedium.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Increase button
                      GestureDetector(
                        onTap: fs < 2.0
                            ? () {
                                ref
                                    .read(aiQaSettingsProvider.notifier)
                                    .setChatFontSize(
                                      (fs + 0.1).clamp(0.7, 2.0),
                                    );
                              }
                            : null,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: fs < 2.0
                                ? colors.surfaceContainerHighest
                                : colors.surfaceContainerHighest.withValues(
                                    alpha: 0.3,
                                  ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: fs < 2.0
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Settings & actions ──
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 18,
                        color: settings.isValid
                            ? colors.onSurfaceVariant
                            : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Text(loc.vimamsaSettings),
                    ],
                  ),
                ),
                if (messages.isNotEmpty || currentThreadId != null) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: colors.error,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          loc.clearChat,
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
      body: Focus(
        focusNode: _chatFocusNode,
        autofocus: true,
        onKeyEvent: _handleChatNavigationKey,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            // Cmd/Ctrl + N: New chat
            const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                _startNewChat,
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
                _startNewChat,
            // Cmd/Ctrl + F: Search in thread
            const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _showInThreadSearch,
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                _showInThreadSearch,
            // Cmd/Ctrl + +: Increase font size
            const SingleActivator(LogicalKeyboardKey.equal, control: true): () {
              final fs = ref.read(aiQaSettingsProvider).chatFontSize;
              ref
                  .read(aiQaSettingsProvider.notifier)
                  .setChatFontSize((fs + 0.1).clamp(0.7, 2.0));
            },
            const SingleActivator(LogicalKeyboardKey.equal, meta: true): () {
              final fs = ref.read(aiQaSettingsProvider).chatFontSize;
              ref
                  .read(aiQaSettingsProvider.notifier)
                  .setChatFontSize((fs + 0.1).clamp(0.7, 2.0));
            },
            // Cmd/Ctrl + -: Decrease font size
            const SingleActivator(LogicalKeyboardKey.minus, control: true): () {
              final fs = ref.read(aiQaSettingsProvider).chatFontSize;
              ref
                  .read(aiQaSettingsProvider.notifier)
                  .setChatFontSize((fs - 0.1).clamp(0.7, 2.0));
            },
            const SingleActivator(LogicalKeyboardKey.minus, meta: true): () {
              final fs = ref.read(aiQaSettingsProvider).chatFontSize;
              ref
                  .read(aiQaSettingsProvider.notifier)
                  .setChatFontSize((fs - 0.1).clamp(0.7, 2.0));
            },
            // Cmd/Ctrl + 0: Reset font size
            const SingleActivator(
              LogicalKeyboardKey.digit0,
              control: true,
            ): () {
              ref.read(aiQaSettingsProvider.notifier).setChatFontSize(1.0);
            },
            const SingleActivator(LogicalKeyboardKey.digit0, meta: true): () {
              ref.read(aiQaSettingsProvider.notifier).setChatFontSize(1.0);
            },
          },
          child: body,
        ),
      ),
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
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(settings.chatFontSize)),
      child: Stack(
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
                        onEditMessage: (message) => _showEditDialog(message),
                        onRetryMessage: () {
                          // Regenerate the last answer in place with a
                          // "think harder" instruction — no duplicate
                          // user prompt is appended.
                          ref
                              .read(aiQaProvider.notifier)
                              .regenerateLastResponse();
                        },
                      ),
              ),

              // ── Attachment chips bar ──────────────────────────────────
              if (attachments.isNotEmpty) const AttachmentBar(),

              // ── Input bar ─────────────────────────────────────────────
              _AiQaInputBar(
                isLoading: isLoading,
                textController: _textController,
                focusNode: _focusNode,
                onSend: _sendMessage,
                onStop: () => ref.read(aiQaProvider.notifier).stopGeneration(),
                layerLink: _mentionLayerLink,
                onKeyEvent: _handleKeyEvent,
              ),

              // ── Compact meta row below the textbox: orthodox toggle ───
              // plus quick tool/answer model switchers.
              _InputMetaRow(colors: colors),
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
      ),
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
          Expanded(
            child: Text(
              _featureName,
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18, color: colors.onSurfaceVariant),
            tooltip: AppLocalizations.of(context).newChat,
            visualDensity: VisualDensity.compact,
            onPressed: _startNewChat,
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            onSelected: (value) {
              switch (value) {
                case 'history':
                  _showHistorySheet();
                  break;
                case 'settings':
                  showAiQaSettingsSheet(context);
                  break;
                case 'clear':
                  ref.read(aiQaProvider.notifier).clearChat();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context).chatHistory),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(
                      Icons.tune,
                      size: 16,
                      color: settings.isValid
                          ? colors.onSurfaceVariant
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context).vimamsaSettings),
                  ],
                ),
              ),
              if (messages.isNotEmpty) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: colors.error),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).clearChat,
                        style: TextStyle(color: colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
                  AppLocalizations.of(
                    context,
                  ).queriesRemainingInThread(remaining),
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
    final provider = ref.watch(aiQaSettingsProvider.select((s) => s.provider));
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
      ),
      child: AiErrorCard(
        error: error,
        provider: provider,
        onClose: () => ref.read(aiQaProvider.notifier).clearError(),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isLoading,
    AiQaSettings settings,
    ColorScheme colors,
  ) {
    final quickActions = widget.quickActions;
    // Reader AI sheet mode: just the quick-ask buttons, centered — no
    // logo/title/history chrome (the sheet header already names the
    // chapter). Falls through to the default empty state otherwise.
    if (quickActions != null && quickActions.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!settings.isValid) ...[
                FilledButton.tonalIcon(
                  onPressed: () => showAiQaSettingsSheet(context),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(AppLocalizations.of(context).configureApiKey),
                ),
                const SizedBox(height: 24),
              ],
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in quickActions)
                    FilledButton.tonalIcon(
                      onPressed: isLoading
                          ? null
                          : () => _runQuickAction(action.prompt),
                      icon: Icon(action.icon, size: 18),
                      label: Text(action.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _featureName,
              style: AppTypography.headlineLarge.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            if (!settings.isValid)
              FilledButton.tonalIcon(
                onPressed: () => showAiQaSettingsSheet(context),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(AppLocalizations.of(context).configureApiKey),
              ),

            const SizedBox(height: 24),
            // History button
            OutlinedButton.icon(
              onPressed: _showHistorySheet,
              icon: const Icon(Icons.history, size: 18),
              label: Text(AppLocalizations.of(context).chatHistory),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  IN-THREAD SEARCH SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _InThreadSearchSheet extends StatefulWidget {
  final List<AiQaMessage> messages;
  final ColorScheme colors;

  const _InThreadSearchSheet({required this.messages, required this.colors});

  @override
  State<_InThreadSearchSheet> createState() => _InThreadSearchSheetState();
}

class _InThreadSearchSheetState extends State<_InThreadSearchSheet> {
  final _searchController = TextEditingController();
  List<AiQaMessage> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.messages;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results = widget.messages);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _results = widget.messages
          .where((m) => m.text.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: widget.colors.surface,
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
                color: widget.colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: 4,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchInThread,
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: widget.colors.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),
          // Results
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).noResultsFound,
                      style: AppTypography.labelMedium.copyWith(
                        color: widget.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) {
                      final msg = _results[i];
                      final q = _searchController.text.toLowerCase();
                      final preview = _highlightMatch(msg.text, q);
                      return ListTile(
                        leading: Icon(
                          msg.isUser ? Icons.person : Icons.smart_toy,
                          size: 16,
                          color: widget.colors.onSurfaceVariant,
                        ),
                        title: preview,
                        subtitle: Text(
                          msg.isUser ? 'User' : 'Assistant',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 10,
                            color: widget.colors.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _highlightMatch(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(
          color: widget.colors.onSurface,
        ),
      );
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx < 0) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(
          color: widget.colors.onSurface,
        ),
      );
    }
    final start = (idx - 20).clamp(0, text.length);
    final end = (idx + query.length + 40).clamp(0, text.length);
    var display = text.substring(start, end);
    if (start > 0) display = '…$display';
    if (end < text.length) display = '$display…';
    return Text.rich(
      TextSpan(children: _buildHighlightedSpans(display, query)),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<TextSpan> _buildHighlightedSpans(String text, String query) {
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    int lastEnd = 0;
    for (final match in query.allMatches(lower)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: AppTypography.labelSmall.copyWith(
              color: widget.colors.onSurface,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: AppTypography.labelSmall.copyWith(
            color: widget.colors.onSurface,
            backgroundColor: widget.colors.primary.withValues(alpha: 0.2),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: AppTypography.labelSmall.copyWith(
            color: widget.colors.onSurface,
          ),
        ),
      );
    }
    return spans;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  THREAD HISTORY BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _ThreadHistorySheet extends ConsumerStatefulWidget {
  const _ThreadHistorySheet();

  @override
  ConsumerState<_ThreadHistorySheet> createState() =>
      _ThreadHistorySheetState();
}

class _ThreadHistorySheetState extends ConsumerState<_ThreadHistorySheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final threadsAsync = ref.watch(chatThreadsProvider);

    return DraggableScrollableSheet(
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

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).searchHistory,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),

              const Divider(height: 1),

              // Thread list
              Expanded(
                child: threadsAsync.when(
                  data: (threads) {
                    // Filter threads by search query
                    final filtered = _searchQuery.trim().isEmpty
                        ? threads
                        : threads
                              .where(
                                (t) => t.title.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ),
                              )
                              .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.trim().isEmpty
                              ? AppLocalizations.of(context).noConversationsYet
                              : AppLocalizations.of(context).noResultsFound,
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final thread = filtered[index];
                        return _ThreadHistoryTile(thread: thread);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      AppLocalizations.of(context).errorMessage(e.toString()),
                    ),
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
          isActive
              ? Icons.chat
              : (thread.isPinned ? Icons.push_pin : Icons.chat_bubble_outline),
          size: 16,
          color: isActive
              ? colors.primary
              : (thread.isPinned ? colors.primary : colors.onSurfaceVariant),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              thread.title,
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (thread.isPinned)
            Icon(
              Icons.push_pin,
              size: 12,
              color: colors.primary.withValues(alpha: 0.6),
            ),
        ],
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
                switch (value) {
                  case 'pin':
                    ref
                        .read(chatHistoryNotifierProvider)
                        .toggleThreadPinned(thread.id);
                    break;
                  case 'delete':
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          AppLocalizations.of(context).deleteConversation,
                        ),
                        content: Text(
                          AppLocalizations.of(
                            context,
                          ).deleteThreadConfirm(thread.title),
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
                    break;
                }
              },
              itemBuilder: (ctx) {
                final loc = AppLocalizations.of(context);
                return [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                          thread.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(thread.isPinned ? loc.unpinThread : loc.pinThread),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: colors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(loc.delete, style: TextStyle(color: colors.error)),
                      ],
                    ),
                  ),
                ];
              },
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

  /// Callback when user taps "edit" on a user message.
  final void Function(AiQaMessage message)? onEditMessage;

  /// Callback when user taps "retry" on an assistant message.
  final VoidCallback? onRetryMessage;

  const AiQaMessageListView({
    super.key,
    required this.scrollController,
    required this.messages,
    this.latestResponseKey,
    this.onEditMessage,
    this.onRetryMessage,
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
          onEdit: message.isUser && onEditMessage != null
              ? () => onEditMessage!(message)
              : null,
          onRetry: !message.isUser && onRetryMessage != null
              ? onRetryMessage
              : null,
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

    return listContent;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ANSWER MODE TOGGLE
// ═══════════════════════════════════════════════════════════════════════════

/// Compact single-line meta row below the textbox: an orthodox text
/// button plus two quick model switchers (tool / answer).
///
/// Orthodox on = text lit in the primary colour; off = dimmed/disabled
/// look. Model buttons open a small edit dialog to swap the model name.
class _InputMetaRow extends ConsumerWidget {
  final ColorScheme colors;

  const _InputMetaRow({required this.colors});

  /// Shorten long model ids for the button label: drop the org prefix
  /// (`google/...`), `:free` / `-latest` noise, and the `gemini-` prefix
  /// only when still too long — e.g. `google/gemini-2.5-flash-lite:free`
  /// becomes `2.5-flash-lite`.
  static String _shortModel(String model) {
    var s = model.trim();
    final slash = s.lastIndexOf('/');
    if (slash >= 0) s = s.substring(slash + 1);
    final lower = s.toLowerCase();
    if (lower.endsWith(':free')) s = s.substring(0, s.length - 5);
    if (s.toLowerCase().endsWith('-latest')) {
      s = s.substring(0, s.length - 7);
    }
    const max = 16;
    if (s.length > max && s.toLowerCase().startsWith('gemini-')) {
      s = s.substring(7);
    }
    if (s.length > max) s = '…${s.substring(s.length - max)}';
    return s;
  }

  static Future<void> _pickModel(
    BuildContext context,
    WidgetRef ref, {
    required bool isTool,
  }) async {
    final settings = ref.read(aiQaSettingsProvider);
    final current = isTool ? settings.toolModel : settings.answerModel;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _ModelPickerSheet(isTool: isTool, current: current),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiQaSettingsProvider);
    final loc = AppLocalizations.of(context);
    final orthodox = settings.orthodoxMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Row(
        children: [
          // Strict toggle button: filled-tonal when on, outlined when
          // off — both obviously tappable. Tooltips explain the mode.
          Tooltip(
            message: orthodox ? loc.orthodoxDesc : loc.unorthodoxDesc,
            child: orthodox
                ? FilledButton.tonalIcon(
                    onPressed: () => ref
                        .read(aiQaSettingsProvider.notifier)
                        .setOrthodoxMode(false),
                    icon: const Icon(Icons.verified_outlined, size: 14),
                    label: Text(
                      loc.strict,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => ref
                        .read(aiQaSettingsProvider.notifier)
                        .setOrthodoxMode(true),
                    icon: Icon(
                      Icons.verified_outlined,
                      size: 14,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    label: Text(
                      loc.strict,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
          ),
          const Spacer(),
          // Tool model switcher.
          TextButton.icon(
            onPressed: () => _pickModel(context, ref, isTool: true),
            icon: Icon(
              Icons.build_outlined,
              size: 12,
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            label: Text(
              _shortModel(settings.toolModel),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 10,
                fontFamily: 'monospace',
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          // Answer model switcher.
          TextButton.icon(
            onPressed: () => _pickModel(context, ref, isTool: false),
            icon: Icon(
              Icons.auto_awesome_outlined,
              size: 12,
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            label: Text(
              _shortModel(settings.answerModel),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 10,
                fontFamily: 'monospace',
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet model picker for the quick switchers: lists the models
/// reported by the current provider and saves the tapped one. No typing.
class _ModelPickerSheet extends ConsumerStatefulWidget {
  final bool isTool;
  final String current;

  const _ModelPickerSheet({required this.isTool, required this.current});

  @override
  ConsumerState<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends ConsumerState<_ModelPickerSheet> {
  late final Future<AiModelFetchResult> _future;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiQaSettingsProvider);
    _future = AiModelService.fetchModels(
      provider: settings.provider,
      apiKey: settings.apiKey,
      baseUrl: settings.baseUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isTool ? loc.toolModelLabel : loc.answerModelLabel,
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<AiModelFetchResult>(
                future: _future,
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final result = snap.data!;
                  if (!result.isSuccess) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        result.error ?? '',
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.error,
                        ),
                      ),
                    );
                  }
                  final models = List<String>.from(result.models);
                  if (!models.contains(widget.current)) {
                    models.insert(0, widget.current);
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: models.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (c, i) {
                      final m = models[i];
                      final selected = m == widget.current;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          m,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check, size: 18, color: colors.primary)
                            : null,
                        onTap: () async {
                          final notifier = ref.read(
                            aiQaSettingsProvider.notifier,
                          );
                          if (widget.isTool) {
                            await notifier.setToolModel(m);
                          } else {
                            await notifier.setAnswerModel(m);
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
  final VoidCallback? onStop;
  final LayerLink layerLink;
  final KeyEventHandler onKeyEvent;

  const _AiQaInputBar({
    required this.isLoading,
    required this.textController,
    required this.focusNode,
    required this.onSend,
    this.onStop,
    required this.layerLink,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
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
        MediaQuery.of(context).padding.bottom + 2,
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
                        : AppLocalizations.of(context).typeAtToAttach,
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
                ? colors.error.withValues(alpha: 0.1)
                : colors.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: isLoading ? onStop : (isThreadFull ? null : onSend),
              child: _StopOrSendButton(
                isLoading: isLoading,
                isThreadFull: isThreadFull,
                colors: colors,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STOP / SEND ANIMATED BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _StopOrSendButton extends StatefulWidget {
  final bool isLoading;
  final bool isThreadFull;
  final ColorScheme colors;

  const _StopOrSendButton({
    required this.isLoading,
    required this.isThreadFull,
    required this.colors,
  });

  @override
  State<_StopOrSendButton> createState() => _StopOrSendButtonState();
}

class _StopOrSendButtonState extends State<_StopOrSendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.isLoading) _glowController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StopOrSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isLoading && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowOpacity = widget.isLoading ? _glowAnimation.value * 0.6 : 0.0;
        return Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: widget.isLoading
                ? [
                    BoxShadow(
                      color: widget.colors.error.withValues(alpha: glowOpacity),
                      blurRadius: 12 + glowOpacity * 8,
                      spreadRadius: 2 + glowOpacity * 4,
                    ),
                  ]
                : null,
          ),
          child: widget.isLoading
              ? Icon(Icons.stop_rounded, color: widget.colors.error, size: 24)
              : Icon(
                  widget.isThreadFull ? Icons.lock : Icons.arrow_upward,
                  color: widget.isThreadFull
                      ? widget.colors.onSurfaceVariant.withValues(alpha: 0.4)
                      : widget.colors.surface,
                  size: 20,
                ),
        );
      },
    );
  }
}

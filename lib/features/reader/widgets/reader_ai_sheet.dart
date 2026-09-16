// lib/features/reader/widgets/reader_ai_sheet.dart
//
// Ask-Vīmaṃsā sheet/dialog for the reader toolbar.
//
// Mobile shows a modal bottom sheet, desktop shows a centered dialog (via
// [showScreenDialog]). Both embed the real [VimamsaScreen] in panel mode so
// there is a single source of truth for chat state — this shell only adds
// a slim header (chapter name + new chat + close) and the centered
// quick-ask buttons, and attaches the current section as context.
//
// State / performance notes:
//   * The shell watches no chat state at all (quick actions live in
//     VimamsaScreen's empty state), so per-token streaming never rebuilds
//     the sheet chrome.
//   * The current section is attached once per open (post-frame, guarded
//     against duplicates) as a heading attachment. Vīmaṃsā fetches the
//     actual text via its tools — no large prompt is built up-front.
//   * Existing user attachments are never cleared or replaced.
//   * All colors come from the theme (no fixed colors anywhere).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/widgets/screen_dialog.dart';
import '../../ai_qa/models/heading_attachment.dart';
import '../../ai_qa/providers/ai_qa_provider.dart';
import '../../ai_qa/providers/mention_provider.dart';
import '../../ai_qa/screens/ai_qa_screen.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';
import '../services/reader_ai_service.dart';

/// Opens the Ask-AI surface for the current reader section.
///
/// Mobile: modal bottom sheet. Desktop (wide window in the desktop shell):
/// centered dialog. Attaches the current section once, then embeds
/// [VimamsaScreen] (panel mode, header hidden) so the user can ask
/// free-form questions.
void showReaderAiSheet({
  required BuildContext context,
  required WidgetRef ref,
  required ReaderTabInfo activeTab,
  required ReaderDataState readerState,
}) {
  final bookName = readerState.bookName ?? activeTab.bookId;
  final section = ReaderAiService.getCurrentSectionInfo(
    readerState: readerState,
    activeTab: activeTab,
  );
  final attachment = HeadingAttachment.create(
    bookId: activeTab.bookId,
    paraId: section.paraId ?? activeTab.currentParaId ?? 0,
    title: section.title ?? bookName,
    bookName: bookName,
  );

  // Attach the section once (post-frame so we don't mutate provider state
  // during build). Never wipes existing attachments; skips duplicates.
  Future.microtask(() {
    final current = ref.read(attachmentsProvider);
    final alreadyAttached = current.any(
      (a) => a.bookId == attachment.bookId && a.paraId == attachment.paraId,
    );
    if (!alreadyAttached) {
      ref.read(attachmentsProvider.notifier).add(attachment);
    }
  });

  if (ResponsiveBreakpoint.isDesktop(context)) {
    unawaited(
      showScreenDialog(
        context: context,
        child: _ReaderAiContent(
          bookName: bookName,
          attachment: attachment,
          isDialog: true,
        ),
      ),
    );
    return;
  }

  unawaited(
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      // No explicit background color — follows the app's bottom-sheet theme
      // (light and dark).
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          child: _ReaderAiContent(
            bookName: bookName,
            attachment: attachment,
            isDialog: false,
          ),
        ),
      ),
    ),
  );
}

/// Sheet/dialog body: drag handle, chapter header row, then the shared
/// Vīmaṃsā panel (header hidden, quick-ask buttons in its empty state).
class _ReaderAiContent extends ConsumerWidget {
  final String bookName;
  final HeadingAttachment attachment;
  final bool isDialog;

  const _ReaderAiContent({
    required this.bookName,
    required this.attachment,
    required this.isDialog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return SafeArea(
      top: !isDialog,
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (!isDialog)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attachment.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        bookName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 22),
                  tooltip: loc.newChat,
                  onPressed: () =>
                      ref.read(aiQaProvider.notifier).startNewThread(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  tooltip: loc.close,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: VimamsaScreen(
              panelMode: true,
              hidePanelHeader: true,
              quickActions: [
                VimamsaQuickAction(
                  icon: Icons.summarize_outlined,
                  label: loc.summarizeTheChapter,
                  prompt: ReaderAiService.buildSectionQuestion(
                    kind: 'summarize',
                    bookName: bookName,
                    headingTitle: attachment.title,
                  ),
                ),
                VimamsaQuickAction(
                  icon: Icons.lightbulb_outline,
                  label: loc.explain,
                  prompt: ReaderAiService.buildSectionQuestion(
                    kind: 'explain',
                    bookName: bookName,
                    headingTitle: attachment.title,
                  ),
                ),
                VimamsaQuickAction(
                  icon: Icons.spellcheck,
                  label: loc.analyzeGrammar,
                  prompt: ReaderAiService.buildSectionQuestion(
                    kind: 'grammar',
                    bookName: bookName,
                    headingTitle: attachment.title,
                  ),
                ),
                VimamsaQuickAction(
                  icon: Icons.account_tree_outlined,
                  label: loc.mindmap,
                  prompt: ReaderAiService.buildSectionQuestion(
                    kind: 'mindmap',
                    bookName: bookName,
                    headingTitle: attachment.title,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

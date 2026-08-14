// lib/features/reader/services/reader_ai_service.dart
//
// AI prompt construction for the reader, extracted from reader_screen.dart.
// The screen (and its context menu) should not know how to query the
// database or build a long prompt — it only stages one and opens Vimaṃsa AI.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:drift/drift.dart' show Variable;

import '../../../core/providers/database_provider.dart';
import '../../../features/ai_qa/providers/ai_qa_provider.dart'
    show aiQaInitialPromptProvider;
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';
import 'reader_copy_service.dart';

/// Builds and stages Vimaṃsa AI prompts from reader context.
class ReaderAiService {
  ReaderAiService._();

  /// Stage a custom [prompt] into the AI QA screen and open it.
  static void stageCustomPrompt(
    BuildContext context,
    WidgetRef ref,
    String prompt,
  ) {
    ref.read(aiQaInitialPromptProvider.notifier).state = prompt;
    if (context.mounted) context.push('/ai-qa');
  }

  /// Stage an "Explain" prompt for [selectedText] and open Vimaṃsa AI.
  ///
  /// Queries the level=10 heading (section title) from the database to give
  /// the AI section context; the AI uses its get_commentaries tool to fetch
  /// the relevant commentaries (Aṭṭhakathā and Ṭīkā) for the section.
  static Future<void> stageExplainPrompt({
    required BuildContext context,
    required WidgetRef ref,
    required ReaderTabInfo activeTab,
    required String selectedText,
    required String bookName,
    int? currentParaId,
  }) async {
    // Query the level=10 heading (section title) from the database
    String headingContext = '';
    if (currentParaId != null) {
      try {
        final db = await ref.read(epitakaDbProvider.future);
        final rows = await db.customSelect(
          'SELECT title FROM headings '
          'WHERE book_id = ? AND para_id <= ? AND level = 10 '
          'ORDER BY para_id DESC LIMIT 1',
          variables: [
            Variable.withString(activeTab.bookId),
            Variable.withInt(currentParaId),
          ],
        ).get();
        if (rows.isNotEmpty) {
          final title = rows.first.data['title'] as String?;
          if (title != null && title.isNotEmpty) {
            headingContext = 'Section heading: "$title" (para_id=$currentParaId)\n';
          }
        }
      } catch (_) {
        // Silently ignore DB errors
      }
    }

    final paraIdStr = currentParaId != null ? ' at para_id=$currentParaId' : '';
    final prompt =
        'Explain this passage from $bookName (${activeTab.bookId}).\n'
        '$headingContext'
        'Use the get_commentaries tool to fetch the relevant '
        'commentaries (Aṭṭhakathā and Ṭīkā) for this section$paraIdStr.\n\n'
        'Focus on explaining the selected text below, using the '
        'broader section context and commentaries as reference:\n\n'
        '$selectedText';

    if (context.mounted) stageCustomPrompt(context, ref, prompt);
  }

  /// Stage a "Summarize chapter" prompt for the current section and open
  /// Vimaṃsa AI.
  ///
  /// Builds the current chapter/section content — from the nearest heading
  /// at or before [activeTab.currentParaId] up to the next heading (capped
  /// at 150 paragraphs) — and sends it to the AI.
  static void stageChapterSummaryPrompt({
    required BuildContext context,
    required WidgetRef ref,
    required ReaderTabInfo activeTab,
    required ReaderDataState readerState,
  }) {
    final paragraphs = readerState.paragraphs;
    if (paragraphs.isEmpty) return;

    final bookName = readerState.bookName ?? activeTab.bookId;
    final currentParaId = activeTab.currentParaId;
    if (currentParaId == null) return;

    // Find the section start (nearest heading at or before currentParaId)
    int sectionStart = 0;
    String? headingTitle;
    for (int i = paragraphs.length - 1; i >= 0; i--) {
      final p = paragraphs[i];
      if (p.paraId <= currentParaId && p.heading != null) {
        sectionStart = i;
        headingTitle = p.heading!.title;
        break;
      }
    }

    // Find the section end (next heading after sectionStart)
    int sectionEnd = paragraphs.length;
    for (int i = sectionStart + 1; i < paragraphs.length; i++) {
      if (paragraphs[i].heading != null) {
        sectionEnd = i;
        break;
      }
    }

    // Cap at 150 paragraphs to avoid sending too much content
    const int maxParagraphs = 150;
    if (sectionEnd - sectionStart > maxParagraphs) {
      sectionEnd = sectionStart + maxParagraphs;
    }

    // Build the chapter text
    final buf = StringBuffer();
    buf.writeln('Book: $bookName');
    if (headingTitle != null && headingTitle.isNotEmpty) {
      buf.writeln('Section: $headingTitle');
    }
    buf.writeln('');

    for (int i = sectionStart; i < sectionEnd; i++) {
      final para = paragraphs[i];
      for (final line in para.lines) {
        if (line.paliText != null && line.paliText!.trim().isNotEmpty) {
          buf.writeln(ReaderCopyService.stripTags(line.paliText!.trim()));
        }
        for (final entry in line.translations.entries) {
          if (entry.value.trim().isNotEmpty) {
            buf.writeln(ReaderCopyService.stripTags(entry.value.trim()));
          }
        }
      }
      if (i < sectionEnd - 1) buf.writeln();
    }

    final chapterText = buf.toString().trim();
    if (chapterText.isEmpty) return;

    final prompt =
        'Please summarize this chapter from $bookName. '
        'Include the key teachings, main points, and structure:\n\n$chapterText';

    stageCustomPrompt(context, ref, prompt);
  }
}

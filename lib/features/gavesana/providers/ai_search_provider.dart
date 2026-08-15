import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_qa/models/ai_qa_models.dart';
import '../../ai_qa/providers/ai_qa_settings_provider.dart';
import '../../ai_qa/services/ai_api_client.dart';
import '../../search/providers/search_provider.dart';

/// Cap on the number of AI tool calls per Gavesana search.
const int kAiSearchMaxToolCalls = 10;

/// How many passages to pass on to the results view at most.
const int kAiSearchMaxPassages = 60;

/// State of the Gavesana AI search run.
sealed class AiSearchState {
  const AiSearchState();
}

class AiSearchIdle extends AiSearchState {
  const AiSearchIdle();
}

/// The AI is planning & running tool calls (searching the canon).
class AiSearchRunning extends AiSearchState {
  /// Live log of the tool calls made so far.
  final List<ToolCallLog> toolLogs;

  /// How many tool iterations have been used so far.
  final int iterationsUsed;

  /// Search terms the AI has queried so far (for the live chips row).
  final List<String> termsUsed;

  const AiSearchRunning({
    this.toolLogs = const [],
    this.iterationsUsed = 0,
    this.termsUsed = const [],
  });
}

class AiSearchError extends AiSearchState {
  final String message;
  const AiSearchError(this.message);
}

/// A completed AI search — passages have been handed to the normal
/// [searchProvider] results view.
class AiSearchDone extends AiSearchState {
  /// Tool steps that produced the passages (for a summary header).
  final List<ToolCallLog> toolLogs;

  /// Number of distinct passages found.
  final int passageCount;

  /// Search terms the AI actually queried (for the results header chips).
  final List<String> termsUsed;

  const AiSearchDone({
    required this.toolLogs,
    required this.passageCount,
    this.termsUsed = const [],
  });
}

/// Runs the Gavesana AI search: plan → search → collect passages.
///
/// Reuses the exact same tool-calling engine as Vimaṃsa (see
/// [runAiToolLoop] in `ai_api_client.dart`), so Gavesana gets the same
/// search tools against the local Tipitaka databases without any
/// on-device embeddings. The AI decides how to search (up to
/// [kAiSearchMaxToolCalls] tool calls); the passages it gathers are shown
/// through the normal [SearchResultsView].
class AiSearchNotifier extends StateNotifier<AiSearchState> {
  final Ref _ref;

  AiSearchNotifier(this._ref) : super(const AiSearchIdle());

  /// Run an AI search for [query].
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // ── Validate AI settings ───────────────────────────────────────
    var settings = _ref.read(aiQaSettingsProvider);
    if (!settings.isValid) {
      await _ref.read(aiQaSettingsProvider.notifier).load();
      settings = _ref.read(aiQaSettingsProvider);
    }
    if (!settings.isValid) {
      state = const AiSearchError(
        'Please configure your API key in the AI Q&A settings first.',
      );
      return;
    }

    state = const AiSearchRunning();

    try {
      final toolLogs = <ToolCallLog>[];
      final loop = await runAiToolLoop(
        settings: settings,
        systemPrompt: kAiSearchSystemPrompt,
        initialConversation: [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    'Find passages in the Tipitaka relevant to: "$trimmed"',
              },
            ],
          },
        ],
        executeTool: (name, args) => executeAiTool(_ref, name, args),
        onToolUpdate: (logs) {
          toolLogs
            ..clear()
            ..addAll(logs);
          state = AiSearchRunning(
            toolLogs: [...toolLogs],
            iterationsUsed: loopIterationsFromLogs(toolLogs),
            termsUsed: extractSearchTerms(toolLogs),
          );
        },
        maxIterations: kAiSearchMaxToolCalls,
        logTag: 'GAVESANA',
      );

      // ── Collect passages from every tool result ─────────────────
      final passages = <AiPassageRef>[];
      final seen = <String>{};
      void addPassage(String bookId, int paraId, {String? text}) {
        if (bookId.isEmpty || paraId <= 0) return;
        final key = '$bookId:$paraId';
        if (seen.add(key)) {
          passages.add(
            AiPassageRef(bookId: bookId, paraId: paraId, text: text),
          );
        }
      }

      for (final tr in loop.allToolResults) {
        final tool = tr['tool'] as String? ?? '';
        final raw = tr['result'] as String? ?? '';

        dynamic parsed;
        try {
          parsed = jsonDecode(raw);
        } catch (_) {
          continue;
        }

        // Tool results with explicit paragraph references.
        if (tool == 'get_paragraph_content') {
          final map = parsed is Map<String, dynamic> ? parsed : null;
          if (map == null) continue;
          final bookId = (map['book_id'] as String?) ?? '';
          final paragraphs = map['paragraphs'] as List<dynamic>? ?? [];
          for (final p in paragraphs) {
            if (p is Map) {
              addPassage(bookId, (p['para_id'] as num?)?.toInt() ?? 0);
            }
          }
        } else if (tool == 'get_paragraph_content_batch') {
          final list = parsed is List ? parsed : const [];
          for (final item in list) {
            if (item is! Map) continue;
            final bookId = (item['book_id'] as String?) ?? '';
            final content = item['content'];
            if (content is Map) {
              final paragraphs = content['paragraphs'] as List<dynamic>? ?? [];
              for (final p in paragraphs) {
                if (p is Map) {
                  addPassage(bookId, (p['para_id'] as num?)?.toInt() ?? 0);
                }
              }
            }
          }
        } else if (tool == 'get_commentaries') {
          final map = parsed is Map<String, dynamic> ? parsed : null;
          if (map == null) continue;
          final commentaries = map['commentaries'] as List<dynamic>? ?? [];
          for (final c in commentaries) {
            if (c is Map) {
              addPassage(
                (c['book_id'] as String?) ?? '',
                (c['para_id'] as num?)?.toInt() ?? 0,
              );
            }
          }
        } else if (tool == 'search_sections') {
          final map = parsed is Map<String, dynamic> ? parsed : null;
          if (map == null) continue;
          final results = map['results'] as List<dynamic>? ?? [];
          for (final r in results) {
            if (r is Map) {
              addPassage(
                (r['book_id'] as String?) ?? '',
                (r['para_id'] as num?)?.toInt() ?? 0,
              );
            }
          }
        } else if (tool.startsWith('search_') || tool == 'get_section') {
          // search_tipitaka, search_tipitaka_batch, search_by_category,
          // get_section → a flat list of hits with book_id + para_id.
          final list = parsed is List ? parsed : const [];
          for (final item in list) {
            if (item is! Map) continue;
            final bookId = (item['book_id'] as String?) ?? '';
            final paraId = (item['para_id'] as num?)?.toInt() ?? 0;
            final text = (item['text'] as String?) ?? '';
            addPassage(bookId, paraId, text: text.isNotEmpty ? text : null);
          }
        }
      }

      if (passages.isEmpty) {
        state = AiSearchDone(
          toolLogs: [...toolLogs],
          passageCount: 0,
          termsUsed: extractSearchTerms(toolLogs),
        );
        return;
      }

      // ── Hand the passages to the normal search results view ─────
      await _ref.read(searchProvider.notifier).showAiResults(
            query: trimmed,
            passages: passages.take(kAiSearchMaxPassages).toList(),
          );
      state = AiSearchDone(
        toolLogs: [...toolLogs],
        passageCount: passages.length,
        termsUsed: extractSearchTerms(toolLogs),
      );
    } catch (e) {
      debugPrint('[GAVESANA] AI search failed: $e');
      state = AiSearchError('AI search failed: $e');
    }
  }

  /// Reset to idle (e.g. when the query field is cleared).
  void reset() {
    state = const AiSearchIdle();
  }
}

/// Estimate the iteration count from the number of completed tool calls.
int loopIterationsFromLogs(List<ToolCallLog> logs) {
  // Each model turn usually issues several parallel tool calls; count the
  // number of distinct batches (a rough proxy: total calls, capped).
  return logs.length;
}

/// Extract the search terms the AI actually queried from the tool log.
///
/// Kept in call order, deduplicated (case-insensitive), capped — so the
/// results header can render them as tappable chips; tapping one re-runs
/// the search with that exact term.
List<String> extractSearchTerms(List<ToolCallLog> logs) {
  const maxTerms = 12;
  final seen = <String>{};
  final terms = <String>[];

  void add(String? raw) {
    final term = raw?.trim() ?? '';
    if (term.isEmpty) return;
    if (seen.add(term.toLowerCase())) {
      terms.add(term);
    }
  }

  for (final log in logs) {
    if (terms.length >= maxTerms) break;
    final args = log.arguments;
    switch (log.toolName) {
      case 'search_tipitaka':
      case 'search_sections':
        add(args['query'] as String?);
      case 'search_tipitaka_batch':
      case 'search_by_category':
        for (final q in (args['queries'] as List<dynamic>?) ?? const []) {
          add(q.toString());
        }
      case 'get_dictionary':
        add(args['term'] as String?);
      case 'get_dictionary_batch':
        for (final t in (args['terms'] as List<dynamic>?) ?? const []) {
          add(t.toString());
        }
    }
  }
  return terms;
}

/// Provider for the Gavesana AI search notifier.
final aiSearchProvider = StateNotifierProvider<AiSearchNotifier, AiSearchState>(
  (ref) => AiSearchNotifier(ref),
);

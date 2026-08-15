// lib/features/translator/providers/translator_provider.dart
//
// Runner state machine for the on-device Translation Builder. Watches the
// persisted [translatorSettingsProvider], opens the databases, then walks
// each selected book: sections → chunks → AI → save, publishing live
// progress and a log. Cancellation is cooperative; a cancelled run stops
// between chunks, and a re-run resumes (already-translated lines are
// skipped unless overwrite is on).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/epitaka_database.dart';
import '../../../core/database/translation_database.dart';
import '../../../core/models/translation_version.dart'
    show TranslationFilenameParser;
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/translation_manifest_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/utils/database_initializer.dart';
import '../../ai_qa/providers/ai_qa_settings_provider.dart';
import '../../ai_qa/services/ai_api_client.dart';
import '../../settings/services/download_foreground_service.dart';
import '../../settings/services/download_notification_service.dart';
import '../services/translator_context.dart';
import '../services/translator_engine.dart';
import '../translator_constants.dart';
import '../translator_settings.dart';

/// Phase of a translation run.
enum TranslatorRunPhase {
  idle,
  running,
  done,
  cancelled,
  error,
}

/// One log line shown in the run screen.
class TranslatorLogEntry {
  final String text;
  final bool isError;

  const TranslatorLogEntry(this.text, {this.isError = false});
}

/// Live state of the translation run.
class TranslatorRunState {
  final TranslatorRunPhase phase;
  final String? error;

  /// Index of the book currently being processed (0-based).
  final int currentBookIndex;
  final int totalBooks;

  /// Index of the section being processed within the current book.
  final int currentSection;
  final int totalSections;

  /// Index of the chunk being processed within the current section.
  final int currentChunk;
  final int totalChunks;

  final int translationsSaved;
  final int glossarySaved;
  final int remarksSaved;

  /// Total pending sentences discovered across all selected books.
  final int pendingSentences;

  /// Sentences + estimated tokens in the chunk currently being processed.
  final int currentChunkSentences;
  final int currentChunkTokens;

  /// Size of the prompt sent for the current chunk (bytes).
  final int currentChunkPromptBytes;

  /// Number of AI calls completed so far.
  final int apiCalls;

  /// Absolute paths of the saved last-chunk prompt/response files (kept
  /// for the "share prompt & response" button; overwritten every chunk).
  final String? lastPromptPath;
  final String? lastResponsePath;

  final List<TranslatorLogEntry> logs;

  const TranslatorRunState({
    this.phase = TranslatorRunPhase.idle,
    this.error,
    this.currentBookIndex = 0,
    this.totalBooks = 0,
    this.currentSection = 0,
    this.totalSections = 0,
    this.currentChunk = 0,
    this.totalChunks = 0,
    this.translationsSaved = 0,
    this.glossarySaved = 0,
    this.remarksSaved = 0,
    this.pendingSentences = 0,
    this.currentChunkSentences = 0,
    this.currentChunkTokens = 0,
    this.currentChunkPromptBytes = 0,
    this.apiCalls = 0,
    this.lastPromptPath,
    this.lastResponsePath,
    this.logs = const [],
  });

  bool get isRunning => phase == TranslatorRunPhase.running;

  TranslatorRunState copyWith({
    TranslatorRunPhase? phase,
    String? error,
    int? currentBookIndex,
    int? totalBooks,
    int? currentSection,
    int? totalSections,
    int? currentChunk,
    int? totalChunks,
    int? translationsSaved,
    int? glossarySaved,
    int? remarksSaved,
    int? pendingSentences,
    int? currentChunkSentences,
    int? currentChunkTokens,
    int? currentChunkPromptBytes,
    int? apiCalls,
    String? lastPromptPath,
    String? lastResponsePath,
    List<TranslatorLogEntry>? logs,
  }) {
    return TranslatorRunState(
      phase: phase ?? this.phase,
      error: error,
      currentBookIndex: currentBookIndex ?? this.currentBookIndex,
      totalBooks: totalBooks ?? this.totalBooks,
      currentSection: currentSection ?? this.currentSection,
      totalSections: totalSections ?? this.totalSections,
      currentChunk: currentChunk ?? this.currentChunk,
      totalChunks: totalChunks ?? this.totalChunks,
      translationsSaved: translationsSaved ?? this.translationsSaved,
      glossarySaved: glossarySaved ?? this.glossarySaved,
      remarksSaved: remarksSaved ?? this.remarksSaved,
      pendingSentences: pendingSentences ?? this.pendingSentences,
      currentChunkSentences:
          currentChunkSentences ?? this.currentChunkSentences,
      currentChunkTokens: currentChunkTokens ?? this.currentChunkTokens,
      currentChunkPromptBytes:
          currentChunkPromptBytes ?? this.currentChunkPromptBytes,
      apiCalls: apiCalls ?? this.apiCalls,
      lastPromptPath: lastPromptPath ?? this.lastPromptPath,
      lastResponsePath: lastResponsePath ?? this.lastResponsePath,
      logs: logs ?? this.logs,
    );
  }
}

class TranslatorRunner extends StateNotifier<TranslatorRunState> {
  TranslatorRunner(this._ref) : super(const TranslatorRunState());

  final Ref _ref;

  bool _cancelRequested = false;

  /// Completed by [cancel] to interrupt an in-flight AI call immediately
  /// (the HTTP request races it and throws [AiCallCancelledException]).
  /// Replaced with a fresh completer at the start of every run.
  Completer<void> _cancelSignal = Completer<void>();

  /// Keys available for this run (from translator settings, falling back
  /// to the AI Q&A key). Round-robined across chunks to spread rate limits.
  List<String> _keyPool = [];
  int _keyIndex = 0;

  /// Next key in round-robin order.
  String _nextKey() {
    if (_keyPool.isEmpty) return '';
    final key = _keyPool[_keyIndex % _keyPool.length];
    _keyIndex++;
    return key;
  }

  void cancel() {
    if (state.isRunning && !_cancelSignal.isCompleted) {
      _cancelRequested = true;
      // Interrupt any in-flight AI call instead of waiting for it.
      _cancelSignal.complete();
      _log('Cancelling — stopping after the current chunk…');
    }
  }

  void _log(String text, {bool isError = false}) {
    final entry = TranslatorLogEntry(text, isError: isError);
    state = state.copyWith(logs: [...state.logs, entry]);
  }

  /// Reset to idle (clears logs and totals).
  void reset() {
    state = const TranslatorRunState();
    _cancelRequested = false;
    _cancelSignal = Completer<void>();
  }

  /// Whether an Android foreground service notification is active for this
  /// run (vs the local-notification fallback). Set on start.
  bool _fgsActive = false;

  /// Push the run's current position into the status-bar notification
  /// (foreground service on Android, plain local notification otherwise).
  void _updateNotification(TranslatorRunState s) {
    final langName =
        translatorLangName(_ref.read(translatorSettingsProvider).langCode);
    final title = 'Translating → $langName';
    final text = _notificationText(s);
    if (_fgsActive) {
      DownloadForegroundService.instance.updateTranslation(
        title: title,
        text: text,
      );
    } else {
      DownloadNotificationService.instance.showTranslatorRunProgress(
        title: title,
        body: text,
        progress: _overallProgress(s),
      );
    }
  }

  /// Overall progress 0..1 (books completed + current book's fraction).
  double _overallProgress(TranslatorRunState s) {
    if (s.totalBooks == 0) return 0;
    final completed = s.currentBookIndex;
    final bookFraction = s.totalSections == 0
        ? 0.0
        : ((s.currentSection - 1) + (s.totalChunks == 0 ? 0.0 : s.currentChunk / s.totalChunks)) /
            s.totalSections;
    return ((completed + bookFraction) / s.totalBooks).clamp(0.0, 1.0);
  }

  String _notificationText(TranslatorRunState s) {
    final b = s.currentBookIndex + 1;
    final t = s.totalBooks;
    if (s.phase != TranslatorRunPhase.running) {
      return '${s.translationsSaved} translated';
    }
    final parts = <String>[
      'book $b/$t',
      if (s.totalSections > 0) 'section ${s.currentSection}/${s.totalSections}',
      if (s.totalChunks > 0) 'chunk ${s.currentChunk}/${s.totalChunks}',
      if (s.currentChunkSentences > 0)
        '${s.currentChunkSentences} sentences',
      if (s.currentChunkTokens > 0) '~${s.currentChunkTokens} tok',
      '${s.translationsSaved} done',
    ];
    return parts.join(' · ');
  }

  /// Run the translator for all selected books.
  Future<void> run() async {
    if (state.isRunning) return;

    _cancelRequested = false;
    // Fresh signal per run: a stale completed one from a previous run must
    // never abort this one.
    _cancelSignal = Completer<void>();

    final settings = _ref.read(translatorSettingsProvider);

    // Resolve the key pool once: translator keys, else the AI Q&A key.
    final aiSettings = _ref.read(aiQaSettingsProvider);
    _keyPool = settings.usableApiKeys;
    if (_keyPool.isEmpty && aiSettings.apiKey.trim().length >= 5) {
      _keyPool = [aiSettings.apiKey.trim()];
    }
    if (_keyPool.isEmpty) {
      state = const TranslatorRunState(
        phase: TranslatorRunPhase.error,
        error: 'Set an API key in the Translation Builder settings first.',
      );
      return;
    }
    _keyIndex = 0;

    state = TranslatorRunState(
      phase: TranslatorRunPhase.running,
      logs: const [],
      totalBooks: settings.bookIds.length,
      // A fresh run must not expose the previous run's last prompt/response.
      lastPromptPath: null,
      lastResponsePath: null,
    );
    _log('Translation Builder started');
    _log('API keys: ${_keyPool.length} configured'
        '${_keyPool.length > 1 ? ' (rotating)' : ''}');
    _log('Target language: ${translatorLangName(settings.langCode)} '
        '(${settings.langCode})');
    _log('Model: ${settings.model}');

    // ── Background keep-alive + status notification ─────────────────
    // On Android this starts the dataSync foreground service so the run
    // keeps going when the app is backgrounded, with live progress in the
    // status bar. Falls back to a plain local notification when the
    // service can't start (e.g. notification permission denied).
    try {
      _fgsActive = await DownloadForegroundService.instance.showTranslation(
        title: 'Translating → ${translatorLangName(settings.langCode)}',
        text: 'Preparing…',
      );
      if (!_fgsActive) {
        // Check why, so the user knows the run won't survive backgrounding.
        final perm =
            await DownloadForegroundService.instance.ensureNotificationPermission();
        if (perm == NotificationPermissionState.permanentlyDenied) {
          _log('Notifications are disabled — the run may pause when the app '
              'is backgrounded. Enable notifications in Settings to keep it '
              'running with live progress.', isError: true);
        }
        DownloadNotificationService.instance.showTranslatorRunProgress(
          title: 'Translating → ${translatorLangName(settings.langCode)}',
          body: 'Preparing…',
          progress: 0,
          isIndeterminate: true,
        );
      }
    } catch (e) {
      debugPrint('[TRANSLATOR] notification setup failed: $e');
      _fgsActive = false;
    }

    try {
      final dbDir = await getDatabaseDirectory();
      final epitakaPath = p.join(dbDir.path, 'epitaka.db');
      if (!await File(epitakaPath).exists()) {
        throw Exception('epitaka.db not found — the core database is missing.');
      }
      final epitakaDb = await EpitakaDatabase.open(epitakaPath);

      // Target translation DB (created on first run if missing).
      final langPath = p.join(
        dbDir.path,
        TranslationFilenameParser.build(settings.langCode),
      );
      final langDb = await _openOrCreateTranslationDb(langPath);
      await ensureTranslatorTables(langDb);

      // English reference DB for parallel context (optional).
      final enPath = p.join(dbDir.path, 'epitaka_en.db');
      TranslationDatabase? enDb;
      if (await File(enPath).exists()) {
        try {
          enDb = await TranslationDatabase.open(enPath);
        } catch (e) {
          debugPrint('[TRANSLATOR] Could not open epitaka_en.db: $e');
        }
      }

      final books = settings.bookIds;
      var totalPending = 0;
      for (var bIdx = 0; bIdx < books.length; bIdx++) {
        if (_cancelRequested) break;
        final bookId = books[bIdx];
        state = state.copyWith(currentBookIndex: bIdx);

        final sections = await buildSectionsFromHeadings(
          db: epitakaDb,
          langDb: langDb,
          bookId: bookId,
          paraStart: 1,
          paraEnd: -1,
          minLines: kTranslatorSectionMinLines,
          overwrite: settings.overwrite,
        );
        final merged = mergeSmallSections(sections);
        state = state.copyWith(totalSections: merged.length);

        if (merged.isEmpty) {
          _log('$bookId: nothing to do (already translated).');
          continue;
        }

        _log('═══ $bookId: ${merged.length} section(s) ═══');
        var bookTranslations = 0;
        var bookGlossary = 0;
        var bookRemarks = 0;

        for (var sIdx = 0; sIdx < merged.length; sIdx++) {
          if (_cancelRequested) break;
          final section = merged[sIdx];
          state = state.copyWith(currentSection: sIdx + 1);

          final chunkStart = section.first.paraId;
          final chunkEnd = section.last.paraId;
          final nPending = section
              .fold<int>(0, (sum, para) => sum + para.pending.length);
          totalPending += nPending;
          state = state.copyWith(pendingSentences: totalPending);
          _log('  Section ${sIdx + 1}/${merged.length}: '
              'paras $chunkStart–$chunkEnd ($nPending pending sentence(s))');

          final chunks = chunkParagraphs(
            section,
            maxTokens: settings.chunkMaxTokens,
            maxLines: settings.chunkMaxLines,
          );
          state = state.copyWith(totalChunks: chunks.length);

          for (var cIdx = 0; cIdx < chunks.length; cIdx++) {
            if (_cancelRequested) break;
            final chunk = chunks[cIdx];
            final nSent = chunk
                .fold<int>(0, (sum, para) => sum + para.pending.length);
            final tokens = chunkParagraphsTokens(chunk);
            state = state.copyWith(
              currentChunk: cIdx + 1,
              currentChunkSentences: nSent,
              currentChunkTokens: tokens,
            );

            final result = await _handleChunk(
              settings: settings,
              epitakaDb: epitakaDb,
              langDb: langDb,
              enDb: enDb,
              bookId: bookId,
              chunk: chunk,
            );
            bookTranslations += result.translationsSaved;
            bookGlossary += result.glossarySaved;
            bookRemarks += result.remarksSaved;
            state = state.copyWith(
              translationsSaved: state.translationsSaved +
                  result.translationsSaved,
              glossarySaved:
                  state.glossarySaved + result.glossarySaved,
              remarksSaved: state.remarksSaved + result.remarksSaved,
              apiCalls: state.apiCalls + result.apiCalls,
            );
            _updateNotification(state);
          }
        }
        _log('  $bookId done: $bookTranslations translations, '
            '$bookGlossary glossary, $bookRemarks remarks.');
      }

      // Invalidate the DB provider so the reader picks up new
      // translations, plus the translation-list providers so the built
      // language appears in Settings → Translations & Downloads right away
      // (they scan the DB directory and would otherwise return a stale
      // cached list until the next app launch).
      _ref.invalidate(translationDbProvider(settings.langCode));
      _ref.invalidate(localTranslationVersionsProvider);
      _ref.invalidate(mergedTranslationVersionsProvider);
      _ref.invalidate(translationRegistryProvider);

      final langName = translatorLangName(settings.langCode);
      if (_cancelRequested) {
        state = state.copyWith(phase: TranslatorRunPhase.cancelled);
        _log('Run cancelled.');
        await _finishNotification(
          langName: langName,
          title: 'Translation cancelled',
          body: '${state.translationsSaved} translations saved.',
          isError: false,
        );
      } else {
        state = state.copyWith(phase: TranslatorRunPhase.done);
        _log('═══ Finished. Total: ${state.translationsSaved} '
            'translations, ${state.glossarySaved} glossary, '
            '${state.remarksSaved} remarks ═══');

        // Auto-enable the freshly built language so users can read it in
        // the book immediately (Settings → Translations & Downloads also
        // shows it now, with its own enable switch).
        if (state.translationsSaved > 0) {
          final settingsNotifier = _ref.read(settingsProvider.notifier);
          final appSettings = _ref.read(settingsProvider);
          if (!appSettings.enabledTranslations.contains(settings.langCode)) {
            await settingsNotifier.setTranslationEnabled(
              settings.langCode,
              true,
            );
            _log('Enabled ${translatorLangName(settings.langCode)} for '
                'reading — toggle it off in Settings → Translations & '
                'Downloads if you don\'t want it shown.');
          }
          // Select the default version if none is chosen yet (the builder
          // writes the default epitaka_<lang>.db).
          final currentSuffix =
              appSettings.translationVersionMap[settings.langCode] ?? '';
          if (currentSuffix.isEmpty) {
            await settingsNotifier.setTranslationVersion(
              settings.langCode,
              null,
            );
          }
        }
        await _finishNotification(
          langName: langName,
          title: 'Translation done',
          body: '${state.translationsSaved} translations, '
              '${state.glossarySaved} glossary, '
              '${state.remarksSaved} remarks saved.',
          isError: false,
        );
      }
    } on AiCallCancelledException {
      // User pressed Stop while a chunk's AI call was in flight — the call
      // was interrupted immediately (not waited out).
      state = state.copyWith(phase: TranslatorRunPhase.cancelled);
      _log('Run cancelled.');
      await _finishNotification(
        langName: translatorLangName(settings.langCode),
        title: 'Translation cancelled',
        body: '${state.translationsSaved} translations saved.',
        isError: false,
      );
    } catch (e) {
      debugPrint('[TRANSLATOR] Run failed: $e');
      state = TranslatorRunState(
        phase: TranslatorRunPhase.error,
        error: e.toString(),
        logs: state.logs,
      );
      _log('Error: $e', isError: true);
      await _finishNotification(
        langName: translatorLangName(settings.langCode),
        title: 'Translation failed',
        body: e.toString(),
        isError: true,
      );
    }
  }

  /// Stop the foreground service (or dismiss the local notification) and
  /// show a brief completion/error notification.
  Future<void> _finishNotification({
    required String langName,
    required String title,
    required String body,
    required bool isError,
  }) async {
    if (_fgsActive) {
      await DownloadForegroundService.instance.hideTranslation();
      if (isError) {
        DownloadNotificationService.instance.showTranslatorRunError(title, body);
      } else {
        DownloadNotificationService.instance
            .showTranslatorRunComplete(title, body);
      }
    } else {
      DownloadNotificationService.instance.dismissTranslatorRun();
    }
  }

  /// Open the target translation DB, creating the file + schema if absent.
  Future<TranslationDatabase> _openOrCreateTranslationDb(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
      // Opening a fresh file through drift creates the tables; we then add
      // the translator-specific tables in ensureTranslatorTables.
      final fresh = await TranslationDatabase.open(path);
      await ensureTranslatorTables(fresh);
      return fresh;
    }
    return TranslationDatabase.open(path);
  }

  /// Overwrite the last-chunk prompt + response files (so only the most
  /// recent exchange is kept) and record their paths in the run state.
  Future<void> _saveLastExchange({
    required String systemPrompt,
    required String userPrompt,
    required String raw,
  }) async {
    try {
      final dbDir = await getDatabaseDirectory();
      final promptPath = p.join(dbDir.path, kTranslatorLastPromptFile);
      final responsePath = p.join(dbDir.path, kTranslatorLastResponseFile);
      await File(promptPath).writeAsString(
        '## SYSTEM PROMPT\n$systemPrompt\n\n## USER PROMPT\n$userPrompt\n',
        flush: true,
      );
      await File(responsePath).writeAsString(raw, flush: true);
      state = state.copyWith(
        lastPromptPath: promptPath,
        lastResponsePath: responsePath,
      );
    } catch (e) {
      debugPrint('[TRANSLATOR] Could not save last prompt/response: $e');
    }
  }

  /// Build the context blocks + prompt for one chunk, call the AI, parse,
  /// and save.
  ///
  /// If the assembled prompt (system + user) exceeds
  /// [kTranslatorPromptSizeLimitBytes], the chunk is split in half and each
  /// half is handled recursively (up to [depth] 8, mirroring the server's
  /// `_handle_chunk`). When a chunk is already a single sentence and still
  /// oversized, the commentary / word-definition context blocks are
  /// truncated as a last resort.
  Future<TChunkResult> _handleChunk({
    required TranslatorSettings settings,
    required EpitakaDatabase epitakaDb,
    required TranslationDatabase langDb,
    required TranslationDatabase? enDb,
    required String bookId,
    required List<TParagraph> chunk,
    int depth = 0,
  }) async {
    final chunkStart = chunk.first.paraId;
    final chunkEnd = chunk.last.paraId;
    final ctxStart = chunkStart - 1 < 1 ? 1 : chunkStart - 1;
    final ctxEnd = chunkEnd + 1;

    final paliText = chunk
        .expand((para) => para.pending)
        .map((s) => s.pali)
        .join('\n');

    // ── Build the context blocks in parallel ─────────────────────
    var blocks = await Future.wait([
      buildGlossaryBlock(
        epitakaDb: epitakaDb,
        langDb: langDb,
        paliText: paliText,
      ),
      buildCommentaryBlock(
        db: epitakaDb,
        langDb: langDb,
        enDb: enDb,
        bookId: bookId,
        paraStart: ctxStart,
        paraEnd: ctxEnd,
      ),
      buildPaliDefsBlock(
        db: epitakaDb,
        langDb: langDb,
        enDb: enDb,
        paliText: paliText,
      ),
      buildPreviousParagraphBlock(
        db: epitakaDb,
        langDb: langDb,
        enDb: enDb,
        bookId: bookId,
        paraStart: chunkStart,
      ),
      buildMulaAtthaBlock(
        db: epitakaDb,
        langDb: langDb,
        enDb: enDb,
        bookId: bookId,
        paraStart: ctxStart,
        paraEnd: ctxEnd,
      ),
      buildParallelBlock(
        enDb: enDb,
        bookId: bookId,
        paraStart: ctxStart,
        paraEnd: ctxEnd,
      ),
    ]);

    final systemPrompt = buildTranslatorSystemPrompt(
      langCode: settings.langCode,
      customPrompt: settings.customPrompt,
    );

    String prompt = buildChunkPrompt(
      bookId: bookId,
      paraStart: chunkStart,
      paraEnd: chunkEnd,
      chunk: chunk,
      glossaryBlock: blocks[0],
      commentaryBlock: blocks[1],
      paliDefsBlock: blocks[2],
      prevParaBlock: blocks[3],
      mulaBlock: blocks[4],
      parallelBlock: blocks[5],
    );

    // ── Size-reduction cascade (mirrors server _handle_chunk) ────
    int promptBytes = utf8.encode('$systemPrompt\n\n$prompt').length;
    if (promptBytes > kTranslatorPromptSizeLimitBytes) {
      final halves = splitChunkInHalf(chunk);
      if (halves != null && depth < 8) {
        _log('    [size] p$chunkStart-$chunkEnd: '
            '${(promptBytes / 1024).toStringAsFixed(1)}KB prompt exceeds '
            'the ${(kTranslatorPromptSizeLimitBytes / 1024 / 1024).toStringAsFixed(1)}MB '
            'limit — splitting into 2 smaller chunks');
        final left = await _handleChunk(
          settings: settings,
          epitakaDb: epitakaDb,
          langDb: langDb,
          enDb: enDb,
          bookId: bookId,
          chunk: halves[0],
          depth: depth + 1,
        );
        final right = await _handleChunk(
          settings: settings,
          epitakaDb: epitakaDb,
          langDb: langDb,
          enDb: enDb,
          bookId: bookId,
          chunk: halves[1],
          depth: depth + 1,
        );
        return left + right;
      }
      // Last resort: already one sentence (or depth exhausted) — truncate
      // the commentary + word-definition context for THIS call only.
      _log('    [size] p$chunkStart-$chunkEnd: '
          '${(promptBytes / 1024).toStringAsFixed(1)}KB prompt with a single '
          'pending sentence — truncating commentary/word-def context '
          '(translation quality may be affected here).', isError: true);
      final cap = kTranslatorPromptSizeLimitBytes ~/ 3;
      blocks[1] = blocks[1].length > cap
          ? blocks[1].substring(0, cap)
          : blocks[1];
      blocks[2] = blocks[2].length > cap
          ? blocks[2].substring(0, cap)
          : blocks[2];
      prompt = buildChunkPrompt(
        bookId: bookId,
        paraStart: chunkStart,
        paraEnd: chunkEnd,
        chunk: chunk,
        glossaryBlock: blocks[0],
        commentaryBlock: blocks[1],
        paliDefsBlock: blocks[2],
        prevParaBlock: blocks[3],
        mulaBlock: blocks[4],
        parallelBlock: blocks[5],
      );
      promptBytes = utf8.encode('$systemPrompt\n\n$prompt').length;
    }

    final nSentences = chunk
        .fold<int>(0, (sum, para) => sum + para.pending.length);
    state = state.copyWith(currentChunkPromptBytes: promptBytes);
    _log('    Chunk ${cIdxLabel(chunkStart, chunkEnd)}: '
        '$nSentences sentence(s), prompt '
        '${(promptBytes / 1024).toStringAsFixed(1)}KB '
        '(~${chunkParagraphsTokens(chunk)} tokens)');

    // Round-robin across the configured keys (or the AI Q&A fallback).
    final apiKey = _nextKey();

    final raw = await AiApiClient.callTextModel(
      provider: settings.provider,
      baseUrl: settings.baseUrl,
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      apiKey: apiKey,
      model: settings.model,
      cancelSignal: _cancelSignal.future,
    );

    // Keep only the LAST chunk's prompt + raw response on disk (overwritten
    // every chunk) so the "share prompt & response" button always has the
    // most recent exchange without accumulating data over time.
    await _saveLastExchange(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      raw: raw,
    );

    if (raw.trim().isEmpty) {
      _log('    Chunk ${cIdxLabel(chunkStart, chunkEnd)}: '
          'empty response — skipping.', isError: true);
      return const TChunkResult(apiCalls: 1);
    }

    final parsed = parseAiTranslationResult(raw);
    final translations = parsed.translations;
    final glossary = parsed.glossary;
    final remarks = parsed.remarks;

    // Script-bleed guard: force wrong-script output to low confidence.
    final bleedFlagged = checkTranslationsForScriptBleed(
      settings.langCode,
      translations,
    );
    if (bleedFlagged.isNotEmpty) {
      _log('    ⚠ Script bleed: ${bleedFlagged.length} line(s) marked '
          'low-confidence.', isError: true);
    }

    final savedTrans = await saveTranslations(langDb, bookId, translations);
    final savedRem = await saveRemarks(langDb, bookId, remarks);
    var savedGloss = 0;
    if (glossary.isNotEmpty) {
      savedGloss = await saveGlossaryTerms(
        langDb,
        epitakaDb,
        glossary,
        sourceId: bookId,
        paraIdStart: chunkStart,
        paraIdEnd: chunkEnd,
      );
    }

    _log('    → $savedTrans translations, $savedGloss glossary, '
        '$savedRem remarks.');
    return TChunkResult(
      translationsSaved: savedTrans,
      glossarySaved: savedGloss,
      remarksSaved: savedRem,
      apiCalls: 1,
    );
  }
}

String cIdxLabel(int start, int end) => 'p$start-$end';

/// Provider for the translation runner.
final translatorRunnerProvider =
    StateNotifierProvider<TranslatorRunner, TranslatorRunState>((ref) {
  return TranslatorRunner(ref);
});

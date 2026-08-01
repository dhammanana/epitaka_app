import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;

import '../../../core/database/epitaka_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/database_initializer.dart';
import '../services/tokenizer_service.dart';
import '../services/onnx_service.dart';
import '../services/vector_search_service.dart';
import 'gavesana_download_provider.dart';

/// State of the Gavesana search process.
enum GavesanaState { idle, loadingModel, embedding, searching, ready, error }

/// A single search hit with metadata and text content for display.
class GavesanaSearchHit {
  final int chunkId;

  /// Textual book ID from chunk_metadata (e.g. "dn1", "A-i").
  final String bookId;
  final int startPara;
  final int endPara;
  final int startLine;
  final int endLine;

  /// Vector cosine similarity (1 - distance). Typically a low value
  /// (often < 0.3) for this corpus — kept separate from the fused score.
  final double similarity;

  /// Reciprocal Rank Fusion score from combining vector + BM25 rankings.
  final double rrfScore;

  /// Display score shown in the UI badge. By default this is the RRF score
  /// min-max normalized across the result set to [0,1]; it can optionally be
  /// a weighted blend of normalized vector + BM25 signals (see
  /// [GavesanaNotifier.vectorWeight]).
  double displayScore;

  /// Concatenated Pāli text for the paragraph/line range.
  final String paliText;

  /// Concatenated translation text (from active translation lang).
  final String translation;

  /// Book display name.
  final String bookName;

  GavesanaSearchHit({
    required this.chunkId,
    required this.bookId,
    required this.startPara,
    required this.endPara,
    required this.startLine,
    required this.endLine,
    required this.similarity,
    required this.rrfScore,
    required this.displayScore,
    this.paliText = '',
    this.translation = '',
    this.bookName = '',
  });
}

/// Notifier that manages the entire Gavesana search lifecycle.
class GavesanaNotifier extends StateNotifier<GavesanaState> {
  final Ref _ref;

  GavesanaTokenizerService? _tokenizer;
  GavesanaOnnxService? _onnx;
  GavesanaVectorSearchService? _vectorSearch;

  List<GavesanaSearchHit> _results = [];
  String? _errorMessage;
  bool _initialized = false;

  /// Weight given to the **vector** signal in the display score blend.
  /// BM25 gets the complement (1 - vectorWeight). 0.0 = pure BM25,
  /// 1.0 = pure vector. Default 0.5 (equal). This only affects the
  /// *displayed* score badge; ranking always uses RRF.
  double vectorWeight = 0.5;

  /// Whether the chunk-level BM25 FTS index (`vec_chunks_fts`) has been built
  /// inside epitaka.db. Checked before a search so the UI can prompt the
  /// user to build it via a dialog (never lazily in the background, which
  /// would jank the app).
  bool get isBm25IndexBuilt => _bm25IndexBuilt;
  bool _bm25IndexBuilt = false;

  List<GavesanaSearchHit> get results => _results;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _initialized;

  GavesanaNotifier(this._ref) : super(GavesanaState.idle);

  /// Initialize all services (tokenizer, ONNX, vector DB).
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    state = GavesanaState.loadingModel;

    try {
      final downloadService = _ref.read(gavesanaDownloadServiceProvider);

      // ── Step 1: Check assets ───────────────────────────────
      // Assets are either already downloaded from a previous session,
      // or the user must download them from Settings / first-launch screen.
      if (!await downloadService.areAssetsReady()) {
        _errorMessage =
            'Gavesana assets not found. '
            'Please download them from Settings -> AI Search.';
        state = GavesanaState.error;
        return;
      }

      // ── Step 2: Load tokenizer ───────────────────────────────
      final tokenizerPath = await downloadService.getTokenizerPath();
      if (tokenizerPath == null) {
        _errorMessage = 'Tokenizer file not found.';
        state = GavesanaState.error;
        return;
      }

      _tokenizer = GavesanaTokenizerService();
      await _tokenizer!.load(tokenizerPath);

      // ── Step 3: Load ONNX model ──────────────────────────────
      final modelPath = await downloadService.getModelPath();
      if (modelPath == null) {
        _errorMessage = 'Model file not found.';
        state = GavesanaState.error;
        return;
      }

      _onnx = GavesanaOnnxService();
      await _onnx!.init(modelPath);

      // ── Step 5: Open vector DB + epitaka.db ───────────────────
      final vecDbPath = await downloadService.getVectorDbPath();
      if (vecDbPath == null) {
        _errorMessage = 'Vector database not found.';
        state = GavesanaState.error;
        return;
      }

      final dbDir = await getDatabaseDirectory();
      final epiPath = p.join(dbDir.path, 'epitaka.db');

      _vectorSearch = GavesanaVectorSearchService();
      final opened = await _vectorSearch!.open(vecDbPath, epitakaDbPath: epiPath);
      if (!opened) {
        _errorMessage =
            'Failed to open vector database. '
            'Check console logs for details.';
        state = GavesanaState.error;
        return;
      }

      // ── Step 6: Check whether chunk-level BM25 FTS exists ────
      // (Built on demand via a dialog — see [ensureBm25Index].)
      _bm25IndexBuilt = _vectorSearch!.isChunkFtsBuilt();

      _initialized = true;
      state = GavesanaState.idle;
    } catch (e) {
      _errorMessage = e.toString();
      state = GavesanaState.error;
    }
  }

  /// Search for chunks similar to the given text query.
  ///
  /// Runs vector search (candidate pool ~[vectorTopK]) and BM25 lexical
  /// search (candidate pool ~[bm25Limit]) in parallel, then fuses the two
  /// ranked lists with Reciprocal Rank Fusion (RRF, k=60). RRF uses rank
  /// order only, so the weak/low vector cosine scores don't get drowned
  /// out by BM25 magnitudes.
  ///
  /// [topK] controls how many fused results to return (UI-driven).
  Future<void> search(String query, {int topK = 10}) async {
    if (!_initialized ||
        _onnx == null ||
        _tokenizer == null ||
        _vectorSearch == null) {
      _errorMessage = 'Gavesana not initialized.';
      state = GavesanaState.error;
      return;
    }

    if (query.trim().isEmpty) return;

    state = GavesanaState.embedding;

    try {
      // Generate embedding
      final embedding = await _onnx!.generateEmbedding(_tokenizer!, query);
      state = GavesanaState.searching;

      // ── Parallel retrieval: vector + BM25 ─────────────────────
      // Wide candidate pools so RRF has enough overlap to rank well.
      const vectorTopK = 50;
      const bm25Limit = 100;
      final vectorFuture = _vectorSearch!.search(embedding, topK: vectorTopK);
      final bm25Future = _vectorSearch!.searchBm25(query, limit: bm25Limit);
      final results = await Future.wait([vectorFuture, bm25Future]);
      final vectorResults = results[0] as List<VectorSearchResult>;
      final bm25Results = results[1] as List<Bm25SearchResult>;

      // ── Reciprocal Rank Fusion ────────────────────────────────
      const k = 60;
      final rrf = <int, double>{};
      for (int i = 0; i < vectorResults.length; i++) {
        rrf[vectorResults[i].chunkId] =
            (rrf[vectorResults[i].chunkId] ?? 0) + 1.0 / (k + i + 1);
      }
      for (int i = 0; i < bm25Results.length; i++) {
        rrf[bm25Results[i].chunkId] =
            (rrf[bm25Results[i].chunkId] ?? 0) + 1.0 / (k + i + 1);
      }

      // Sort chunk IDs by fused score, take top-K.
      final ranked = rrf.keys.toList()
        ..sort((a, b) => rrf[b]!.compareTo(rrf[a]!));
      final topChunkIds = ranked.take(topK).toList();

      // ── Build a lookup of vector + bm25 results by chunkId ────
      final vecById = {for (final r in vectorResults) r.chunkId: r};

      // ── Fetch metadata for any chunk missing from vector set ──
      final chunkMeta = <int, VectorSearchResult>{};
      for (final id in topChunkIds) {
        if (vecById.containsKey(id)) {
          chunkMeta[id] = vecById[id]!;
        } else {
          final c = await _vectorSearch!.getChunk(id);
          if (c != null) chunkMeta[id] = c;
        }
      }

      // ── Fetch text content + assemble hits ───────────────────
      final epitakaDb = await _ref.read(epitakaDbProvider.future);
      final settings = _ref.read(settingsProvider);
      final activeLang = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.first
          : (settings.showTranslation ? settings.primaryTranslationLang : null);

      final allBooks = await epitakaDb.select(epitakaDb.books).get();
      final bookNameMap = <String, String>{};
      for (final b in allBooks) {
        bookNameMap[b.bookId] = b.bookName ?? b.bookId;
      }

      final hits = <GavesanaSearchHit>[];
      for (final id in topChunkIds) {
        final meta = chunkMeta[id];
        if (meta == null) continue;
        final bookIdStr = meta.bookId;

        final paliText = await _fetchPaliText(epitakaDb, bookIdStr, meta);
        String translation = '';
        if (activeLang != null) {
          translation = await _fetchTranslation(bookIdStr, meta, activeLang);
        }

        final vecSim = vecById[id]?.similarity ?? 0.0;
        final rrfScore = rrf[id] ?? 0.0;

        hits.add(
          GavesanaSearchHit(
            chunkId: id,
            bookId: bookIdStr,
            startPara: meta.startPara,
            endPara: meta.endPara,
            startLine: meta.startLine,
            endLine: meta.endLine,
            similarity: vecSim,
            rrfScore: rrfScore,
            displayScore: rrfScore, // normalized below
            paliText: paliText,
            translation: translation,
            bookName: bookNameMap[bookIdStr] ?? bookIdStr,
          ),
        );
      }

      // ── Normalize display score across the result set ────────
      _normalizeDisplayScores(hits);

      _results = hits;
      state = GavesanaState.ready;
    } catch (e) {
      _errorMessage = e.toString();
      state = GavesanaState.error;
    }
  }

  /// Normalize the [displayScore] of each hit to [0,1] across the result
  /// set (min-max), so the existing badge coloring / % display keeps
  /// working. When [vectorWeight] != 0.5, the display score becomes a
  /// weighted blend of the normalized vector and BM25 signals instead.
  void _normalizeDisplayScores(List<GavesanaSearchHit> hits) {
    if (hits.isEmpty) return;

    // Always keep the raw RRF ranking; only the *displayed* number changes.
    final rrfMin = hits.map((h) => h.rrfScore).reduce((a, b) => a < b ? a : b);
    final rrfMax = hits.map((h) => h.rrfScore).reduce((a, b) => a > b ? a : b);
    final rrfRange = rrfMax - rrfMin;

    // For the weighted blend we also need normalized vector + bm25 signals.
    final vecMin = hits
        .map((h) => h.similarity)
        .reduce((a, b) => a < b ? a : b);
    final vecMax = hits
        .map((h) => h.similarity)
        .reduce((a, b) => a > b ? a : b);
    final vecRange = vecMax - vecMin;

    for (final h in hits) {
      final rrfN = rrfRange == 0 ? 1.0 : (h.rrfScore - rrfMin) / rrfRange;
      if (vectorWeight == 0.5) {
        // Pure RRF display (default).
        h.displayScore = rrfN;
      } else {
        final vecN = vecRange == 0 ? 0.0 : (h.similarity - vecMin) / vecRange;
        // BM25 rank position normalized as a proxy signal (1 = best rank).
        final bm25N =
            1.0 - rrfN; // inverse of RRF share is a rough lexical proxy
        h.displayScore = vectorWeight * vecN + (1.0 - vectorWeight) * bm25N;
      }
    }
  }

  /// Build the chunk-level BM25 FTS index (`vec_chunks_fts`) inside
  /// epitaka.db, reporting progress so a dialog can show it. This is always
  /// triggered by an explicit user action (a dialog), never lazily.
  ///
  /// [onProgress] receives (0.0–1.0, status message). Returns true on
  /// success. Failures are reported via [onError] and return false; the
  /// vector search still works without BM25.
  Future<bool> ensureBm25Index({
    void Function(double progress, String status)? onProgress,
    void Function(String message)? onError,
  }) async {
    // If the vector search service was never created (init failed), create a
    // lightweight instance that only opens epitaka.db for BM25 operations.
    if (_vectorSearch == null) {
      onProgress?.call(0.0, 'Preparing BM25 index…');
      _vectorSearch = GavesanaVectorSearchService();
      final dbDir = await getDatabaseDirectory();
      final epiPath = p.join(dbDir.path, 'epitaka.db');
      final opened = await _vectorSearch!.openBm25Only(epiPath);
      if (!opened) {
        onError?.call(
          'Cannot build BM25 index — could not open epitaka.db.',
        );
        return false;
      }
    }

    onProgress?.call(0.0, 'Preparing BM25 index…');
    try {
      final dbDir = await getDatabaseDirectory();
      final epiPath = p.join(dbDir.path, 'epitaka.db');
      final built = await _vectorSearch!.buildChunkFts(
        epiPath,
        onProgress: onProgress,
      );
      if (built) {
        _bm25IndexBuilt = true;
        onProgress?.call(1.0, 'BM25 index ready');
      } else {
        onError?.call(
          'Could not build BM25 index (epitaka.db missing?). '
          'Vector search will be used alone.',
        );
      }
      return built;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Rebuild the chunk-level BM25 FTS index from scratch. Drops any existing
  /// `vec_chunks_fts` first (e.g. a half-built one left behind when the app
  /// was killed mid-build), then builds fresh. Same progress/error reporting
  /// as [ensureBm25Index].
  Future<bool> rebuildBm25Index({
    void Function(double progress, String status)? onProgress,
    void Function(String message)? onError,
  }) async {
    if (_vectorSearch == null) return false;
    _vectorSearch!.dropChunkFts();
    _bm25IndexBuilt = false;
    return ensureBm25Index(onProgress: onProgress, onError: onError);
  }

  /// Recompute display scores after the user changes [vectorWeight].
  /// Does NOT re-run the search — only the displayed score badge changes,
  /// the RRF ranking stays the same.
  void rerank() {
    _normalizeDisplayScores(_results);
    // Notify listeners by re-emitting the ready state.
    state = GavesanaState.ready;
  }

  /// Fetch Pāli text covering a chunk's paragraph/line range.
  Future<String> _fetchPaliText(
    EpitakaDatabase epitakaDb,
    String bookIdStr,
    VectorSearchResult r,
  ) async {
    try {
      final rows = await epitakaDb
          .customSelect(
            "SELECT group_concat(pali, ' ') as text FROM sentences "
            'WHERE book_id = ? AND '
            '((para_id = ? AND line_id >= ?) OR '
            '(para_id > ? AND para_id < ?) OR '
            '(para_id = ? AND line_id <= ?))',
            variables: [
              Variable.withString(bookIdStr),
              Variable.withInt(r.startPara),
              Variable.withInt(r.startLine),
              Variable.withInt(r.startPara),
              Variable.withInt(r.endPara),
              Variable.withInt(r.endPara),
              Variable.withInt(r.endLine),
            ],
          )
          .get();
      if (rows.isNotEmpty) {
        return (rows.first.data['text'] as String?) ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Fetch translation text for a chunk's range.
  Future<String> _fetchTranslation(
    String bookIdStr,
    VectorSearchResult r,
    String langCode,
  ) async {
    try {
      final transDb = await _ref.read(translationDbProvider(langCode).future);
      if (transDb == null) return '';

      final rows = await transDb
          .customSelect(
            "SELECT group_concat(translation, ' ') as text FROM sentences "
            'WHERE book_id = ? AND '
            '((para_id = ? AND line_id >= ?) OR '
            '(para_id > ? AND para_id < ?) OR '
            '(para_id = ? AND line_id <= ?))',
            variables: [
              Variable.withString(bookIdStr),
              Variable.withInt(r.startPara),
              Variable.withInt(r.startLine),
              Variable.withInt(r.startPara),
              Variable.withInt(r.endPara),
              Variable.withInt(r.endPara),
              Variable.withInt(r.endLine),
            ],
          )
          .get();
      if (rows.isNotEmpty) {
        return (rows.first.data['text'] as String?) ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Dispose all services.
  @override
  void dispose() {
    _onnx?.dispose();
    _vectorSearch?.dispose();
    super.dispose();
  }
}

/// Provider for the Gavesana search notifier.
final gavesanaProvider = StateNotifierProvider<GavesanaNotifier, GavesanaState>(
  (ref) {
    return GavesanaNotifier(ref);
  },
);

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/epitaka_database.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../services/tokenizer_service.dart';
import '../services/onnx_service.dart';
import '../services/vector_search_service.dart';
import 'gavesana_download_provider.dart';

/// State of the Gavesana search process.
enum GavesanaState {
  idle,
  loadingModel,
  embedding,
  searching,
  ready,
  error,
}

/// A single search hit with metadata and text content for display.
class GavesanaSearchHit {
  final int chunkId;

  /// Textual book ID from chunk_metadata (e.g. "dn1", "A-i").
  final String bookId;
  final int startPara;
  final int endPara;
  final int startLine;
  final int endLine;
  final double similarity;

  /// Concatenated Pāli text for the paragraph/line range.
  final String paliText;

  /// Concatenated translation text (from active translation lang).
  final String translation;

  /// Book display name.
  final String bookName;

  const GavesanaSearchHit({
    required this.chunkId,
    required this.bookId,
    required this.startPara,
    required this.endPara,
    required this.startLine,
    required this.endLine,
    required this.similarity,
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

      // ── Step 1: Check & copy assets ────────────────────────
      // 1a. Try Flutter asset bundle (model + tokenizer)
      if (!await downloadService.areAssetsReady()) {
        await downloadService.tryCopyFromAssets();
      }

      // 1b. Vector DB is intentionally NOT bundled in Flutter assets to
      //     keep the app size small. Try known paths the user may have
      //     pushed the DB to.
      final knownPaths = [
        // App-specific external storage (no extra permissions needed)
        '/sdcard/epitaka_vec.db',
        '/storage/emulated/0/epitaka_vec.db',
      ];
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          knownPaths.add(p.join(extDir.path, 'epitaka_vec.db'));
        }
      } catch (_) {}

      for (final path in knownPaths) {
        final copied = await downloadService.tryCopyVectorDbFromLocal(path);
        if (copied) break;
      }

      // 1c. Final check — all assets must be present & valid
      if (!await downloadService.areAssetsReady()) {
        _errorMessage = 'Gavesana assets not found. '
            'Please download them in Settings ' 
            'or provision epitaka_vec.db manually.';
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

      // ── Step 4: Open vector DB ───────────────────────────────
      final vecDbPath = await downloadService.getVectorDbPath();
      if (vecDbPath == null) {
        _errorMessage = 'Vector database not found.';
        state = GavesanaState.error;
        return;
      }

      _vectorSearch = GavesanaVectorSearchService();
      final opened = await _vectorSearch!.open(vecDbPath);
      if (!opened) {
        _errorMessage = 'Failed to open vector database. '
            'Check console logs for details.';
        state = GavesanaState.error;
        return;
      }

      _initialized = true;
      state = GavesanaState.idle;
    } catch (e) {
      _errorMessage = e.toString();
      state = GavesanaState.error;
    }
  }

  /// Search for chunks similar to the given text query.
  ///
  /// [topK] controls how many results to return (default 10).
  /// After getting vector results, fetches the actual Pāli text and
  /// translation text for each hit from the epitaka/translation DBs.
  Future<void> search(String query, {int topK = 10}) async {
    if (!_initialized || _onnx == null || _tokenizer == null || _vectorSearch == null) {
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

      // Search vector database — bookId comes as TEXT from chunk_metadata
      final vectorResults = await _vectorSearch!.search(embedding, topK: topK);

      // Fetch text content for each hit
      final epitakaDb = await _ref.read(epitakaDbProvider.future);
      final settings = _ref.read(settingsProvider);
      final activeLang = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.first
          : (settings.showTranslation
              ? settings.primaryTranslationLang
              : null);

      // Build book name map from books table (keyed by TEXT bookId)
      final allBooks = await epitakaDb.select(epitakaDb.books).get();
      final bookNameMap = <String, String>{};
      for (final b in allBooks) {
        bookNameMap[b.bookId] = b.bookName ?? b.bookId;
      }

      final hits = <GavesanaSearchHit>[];
      for (final r in vectorResults) {
        // r.bookId is already TEXT (e.g. "dn1") from chunk_metadata
        final bookIdStr = r.bookId;

        // Fetch Pāli text for this chunk's range
        final paliText = await _fetchPaliText(epitakaDb, bookIdStr, r);

        // Fetch translation text
        String translation = '';
        if (activeLang != null) {
          translation = await _fetchTranslation(
            bookIdStr, r, activeLang,
          );
        }

        hits.add(GavesanaSearchHit(
          chunkId: r.chunkId,
          bookId: bookIdStr,
          startPara: r.startPara,
          endPara: r.endPara,
          startLine: r.startLine,
          endLine: r.endLine,
          similarity: r.similarity,
          paliText: paliText,
          translation: translation,
          bookName: bookNameMap[bookIdStr] ?? bookIdStr,
        ));
      }

      _results = hits;
      state = GavesanaState.ready;
    } catch (e) {
      _errorMessage = e.toString();
      state = GavesanaState.error;
    }
  }

  /// Fetch Pāli text covering a chunk's paragraph/line range.
  Future<String> _fetchPaliText(
    EpitakaDatabase epitakaDb,
    String bookIdStr,
    VectorSearchResult r,
  ) async {
    try {
      final rows = await epitakaDb.customSelect(
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
      ).get();
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
      final lang = TranslationLanguage.fromCode(langCode);
      final transDb = await _ref.read(translationDbProvider(lang).future);
      if (transDb == null) return '';

      final rows = await transDb.customSelect(
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
      ).get();
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
final gavesanaProvider =
    StateNotifierProvider<GavesanaNotifier, GavesanaState>((ref) {
  return GavesanaNotifier(ref);
});

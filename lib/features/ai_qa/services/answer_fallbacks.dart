library;

/// Resolve the Vīmaṃsā answer-model fallback chain.
///
/// Rule (Gemini):
///   1. Primary = user's answer model.
///   2. Fallback 1 = same "flash" family but a lower version number
///      (e.g. gemini-2.5-flash -> gemini-2.0-flash, gemini-3.8-flash ->
///      gemini-2.5-flash when that is the highest lower version known).
///   3. Fallback 2 = the flash-lite model used for tool calls; if the tool
///      model is not a flash-lite model, use the latest flash-lite model
///      from the fetched list.
///
/// For non-Gemini providers (or unknown models) the chain is just
/// `[answerModel]` — no heuristic renaming is attempted.
List<String> resolveAnswerFallbacks({
  required String answerModel,
  required String toolModel,
  List<String> availableModels = const [],
}) {
  final primary = answerModel.trim();
  final tool = toolModel.trim();
  if (primary.isEmpty) return const [];
  if (!_isGeminiModel(primary)) return const [];

  final fallbacks = <String>[];
  void add(String m) {
    final v = m.trim();
    if (v.isEmpty || v == primary || fallbacks.contains(v)) return;
    fallbacks.add(v);
    if (fallbacks.length >= 2) return;
  }

  // ── Fallback 1: same flash family, lower version ──────────────────
  final flashModels = availableModels
      .map((m) => m.trim())
      .where((m) => m.isNotEmpty && _isGeminiFlash(m) && !_isFlashLite(m))
      .toList();
  // Available list from the API is sorted descending; keep that order so
  // `.first` is the newest.
  final primaryVersion = _geminiVersion(primary);
  String? lowerFlash;
  if (flashModels.isNotEmpty) {
    for (final m in flashModels) {
      if (m == primary) continue;
      if (primaryVersion != null) {
        final v = _geminiVersion(m);
        if (v == null) continue;
        if (_compareVersions(v, primaryVersion) < 0) {
          lowerFlash = m;
          break;
        }
      } else if (!fallbacks.contains(m)) {
        lowerFlash = m;
        break;
      }
    }
    // Unversioned alias (e.g. gemini-flash-latest) has no numeric version
    // to compare — just pick the newest other flash model.
    if (lowerFlash == null && primaryVersion == null) {
      for (final m in flashModels) {
        if (m != primary) {
          lowerFlash = m;
          break;
        }
      }
    }
  }
  if (lowerFlash != null) {
    add(lowerFlash);
  } else {
    final heuristic = _heuristicLowerFlash(primary, primaryVersion);
    if (heuristic != null) add(heuristic);
  }

  // ── Fallback 2: flash-lite ─────────────────────────────────────────
  if (_isFlashLite(tool)) {
    add(tool);
  } else {
    final liteModels = availableModels
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty && _isFlashLite(m))
        .toList();
    if (liteModels.isNotEmpty) {
      for (final m in liteModels) {
        if (m == primary || fallbacks.contains(m)) continue;
        add(m);
        break;
      }
    } else {
      add('gemini-flash-lite-latest');
    }
  }

  return fallbacks;
}

/// Full attempt chain: primary first, then fallbacks.
List<String> resolveAnswerChain({
  required String answerModel,
  required String toolModel,
  List<String> availableModels = const [],
  List<String>? savedFallbacks,
}) {
  final primary = answerModel.trim();
  if (primary.isEmpty) return const [];
  final fallbacks = (savedFallbacks != null && savedFallbacks.isNotEmpty)
      ? savedFallbacks
            .map((m) => m.trim())
            .where((m) => m.isNotEmpty && m != primary)
            .toList()
      : resolveAnswerFallbacks(
          answerModel: primary,
          toolModel: toolModel,
          availableModels: availableModels,
        );
  return [primary, ...fallbacks.take(2)];
}

bool _isGeminiModel(String m) => m.toLowerCase().startsWith('gemini-');

bool _isGeminiFlash(String m) {
  final lower = m.toLowerCase();
  return lower.startsWith('gemini-') && lower.contains('flash');
}

bool _isFlashLite(String m) => m.toLowerCase().contains('flash-lite');

/// Parse "gemini-X.Y-..." into [X, Y]. Returns null for aliases like
/// gemini-flash-latest.
List<int>? _geminiVersion(String m) {
  final match = RegExp(r'gemini-(\d+)\.(\d+)').firstMatch(m.toLowerCase());
  if (match == null) return null;
  return [int.parse(match.group(1)!), int.parse(match.group(2)!)];
}

int _compareVersions(List<int> a, List<int> b) {
  if (a[0] != b[0]) return a[0].compareTo(b[0]);
  return a[1].compareTo(b[1]);
}

/// Offline heuristic when the fetched list has no lower flash model:
/// decrement the minor version (3.8 -> 3.7), or the major when minor is 0.
String? _heuristicLowerFlash(String primary, List<int>? version) {
  if (version == null) return null;
  final lower = primary.toLowerCase();
  if (!_isGeminiFlash(primary) || _isFlashLite(primary)) return null;
  final major = version[0];
  final minor = version[1];
  final replacement = minor > 0 ? '$major.${minor - 1}' : '${major - 1}.0';
  if (major <= 0) return null;
  final oldTag = 'gemini-$major.$minor';
  if (!lower.contains(oldTag)) return null;
  final idx = lower.indexOf(oldTag);
  return '${primary.substring(0, idx)}gemini-$replacement${primary.substring(idx + oldTag.length)}';
}

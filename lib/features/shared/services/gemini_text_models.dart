library;

/// Shared Gemini text-model helpers for Vīmaṃsā (and the translator).
///
/// The Gemini `models.list` endpoint returns every `generateContent`-capable
/// model — including specialized audio/video/image models such as
/// `gemini-3.8-flash-tts` (GA Sept 2026). Those models accept `generateContent`
/// calls but produce audio, not chat text, so auto-picking "the newest flash
/// model" by plain string sort fills a TTS model into a text field.
///
/// These helpers give one general rule used by model fetching, auto-fill and
/// answer fallbacks: a *text model* is a `gemini-*` id with no specialized
/// output-modality marker in its name. New modality variants (whatever Google
/// names them next) are excluded automatically as long as their ids carry the
/// Name fragments that mark a Gemini model as a specialized non-text-output
/// model (TTS, Live audio dialogue, image/video/music generation, robotics).
/// Matched case-insensitively as substrings against the full model id.
const kGeminiNonTextMarkers = <String>[
  'tts',
  'text-to-speech',
  'speech',
  'live',
  'translate',
  'image',
  'imagen',
  'banana',
  'veo',
  'video',
  'omni',
  'music',
  'lyria',
  'audio',
  'robot',
];

/// Pre-release tags used to prefer a stable model over a preview/beta/exp
/// build of the same version when auto-picking.
const kGeminiPreReleaseMarkers = <String>[
  'preview',
  'beta',
  'alpha',
  'exp',
  'experimental',
  'rc',
];

/// Whether [id] is usable as a Gemini chat/text model for Vīmaṃsā.
///
/// Non-`gemini-` ids (other providers) always return true — this predicate
/// only filters Gemini ids. Empty ids return false.
bool isGeminiTextModel(String id) {
  final lower = id.trim().toLowerCase();
  if (lower.isEmpty) return false;
  if (!lower.startsWith('gemini-')) return true;
  for (final marker in kGeminiNonTextMarkers) {
    if (lower.contains(marker)) return false;
  }
  return true;
}

/// Parse `gemini-X.Y-...` into `[major, minor]`. Returns null for unversioned
/// aliases such as `gemini-flash-latest`.
List<int>? geminiVersion(String id) {
  final match = RegExp(
    r'gemini-(\d+)(?:\.(\d+))?',
  ).firstMatch(id.toLowerCase());
  if (match == null) return null;
  return [int.parse(match.group(1)!), int.parse(match.group(2) ?? '0')];
}

bool _isPreRelease(String id) {
  final lower = id.toLowerCase();
  return kGeminiPreReleaseMarkers.any(lower.contains);
}

/// Newest-first comparator for Gemini model ids: higher version first, then
/// stable before pre-release of the same version, then reverse-lexicographic
/// (matches the previous `.sort((a, b) => b.compareTo(a))` behaviour).
int compareGeminiModelsDesc(String a, String b) {
  final va = geminiVersion(a);
  final vb = geminiVersion(b);
  if (va != null && vb != null) {
    if (va[0] != vb[0]) return vb[0].compareTo(va[0]);
    if (va[1] != vb[1]) return vb[1].compareTo(va[1]);
    final pa = _isPreRelease(a);
    final pb = _isPreRelease(b);
    if (pa != pb) return pa ? 1 : -1;
    return b.compareTo(a);
  }
  if (va != null) return -1;
  if (vb != null) return 1;
  return b.compareTo(a);
}

/// Copy of [models] sorted newest-first (version-aware).
List<String> sortGeminiModelsNewestFirst(Iterable<String> models) {
  final list = models.toList();
  list.sort(compareGeminiModelsDesc);
  return list;
}

bool _isFlashLite(String id) => id.toLowerCase().contains('flash-lite');

/// Best Gemini model for the tool (fast/cheap) role: newest flash-lite
/// *text* model. Falls back to the newest text model, then to the newest
/// model of any kind. Returns null for an empty list.
String? pickBestGeminiToolModel(List<String> models) {
  if (models.isEmpty) return null;
  final text = models.where(isGeminiTextModel).toList();
  final pool = text.isNotEmpty ? text : models.toList();
  final sorted = sortGeminiModelsNewestFirst(pool);
  for (final m in sorted) {
    if (_isFlashLite(m)) return m;
  }
  return sorted.first;
}

/// Best Gemini model for the answer (capable) role: newest flash *text*
/// model excluding flash-lite. Falls back to the newest non-lite text model,
/// then the newest text model. Returns null for an empty list.
String? pickBestGeminiAnswerModel(List<String> models) {
  if (models.isEmpty) return null;
  final text = models.where(isGeminiTextModel).toList();
  final pool = text.isNotEmpty ? text : models.toList();
  final sorted = sortGeminiModelsNewestFirst(pool);
  for (final m in sorted) {
    final lower = m.toLowerCase();
    if (lower.contains('flash') && !_isFlashLite(m)) return m;
  }
  for (final m in sorted) {
    if (!_isFlashLite(m)) return m;
  }
  return sorted.first;
}

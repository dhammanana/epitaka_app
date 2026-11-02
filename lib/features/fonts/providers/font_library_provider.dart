import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/downloadable_font.dart';
import '../services/font_library_service.dart';

/// State of the downloadable font library: the catalog, which fonts are on
/// this device, which one Pāli reading uses, and per-font download progress.
class FontLibraryState {
  final List<DownloadableFont> catalog;
  final Set<String> installed;
  final String? selectedId;

  /// Id → 0…1 while a download runs; absent when idle.
  final Map<String, double> progress;
  final bool loading;
  final String? error;

  const FontLibraryState({
    this.catalog = const <DownloadableFont>[],
    this.installed = const <String>{},
    this.selectedId,
    this.progress = const <String, double>{},
    this.loading = true,
    this.error,
  });

  bool isInstalled(String id) => installed.contains(id);
  bool isSelected(String id) => selectedId == id;
  bool isDownloading(String id) => progress.containsKey(id);

  DownloadableFont? get selected {
    for (final font in catalog) {
      if (font.id == selectedId) return font;
    }
    return null;
  }

  FontLibraryState copyWith({
    List<DownloadableFont>? catalog,
    Set<String>? installed,
    String? selectedId,
    bool clearSelection = false,
    Map<String, double>? progress,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return FontLibraryState(
      catalog: catalog ?? this.catalog,
      installed: installed ?? this.installed,
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      progress: progress ?? this.progress,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Loads the catalog, restores downloaded fonts and drives downloads.
///
/// Selection is applied through [FontLibraryService.applySelection], which
/// updates the global Pāli font resolution in `pali_text_utils`. Widgets that
/// read Pāli text resolve the family at build time, so callers of
/// [select] usually follow up with `settingsProvider.notifier.refresh()`.
class FontLibraryNotifier extends StateNotifier<FontLibraryState> {
  FontLibraryNotifier() : super(const FontLibraryState()) {
    _init();
  }

  final Map<String, double> _progress = <String, double>{};
  bool _disposed = false;

  Future<void> _init() async {
    try {
      final snapshot = await FontLibraryService.instance.restore();
      if (_disposed) return;
      state = FontLibraryState(
        catalog: snapshot.catalog,
        installed: snapshot.installed,
        selectedId: snapshot.selectedId,
        loading: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  /// Downloads [font] and selects it for Pāli reading.
  ///
  /// Errors land in [FontLibraryState.error]; the file is never left
  /// half-written (the service writes a `.part` and renames it).
  Future<void> download(DownloadableFont font) async {
    if (_progress.containsKey(font.id)) return;
    _progress[font.id] = 0;
    _emit();
    try {
      await FontLibraryService.instance.download(
        font,
        onProgress: (value) {
          // The stream fires per chunk; repaint only on a visible step.
          if (value - (_progress[font.id] ?? 0) >= 0.02 || value >= 1) {
            _progress[font.id] = value;
            _emit();
          }
        },
      );
      _progress.remove(font.id);
      state = state.copyWith(
        installed: {...state.installed, font.id},
        clearError: true,
      );
      // Downloading a font is the start of using it — spare the extra tap.
      await select(font);
    } catch (e) {
      _progress.remove(font.id);
      state = state.copyWith(error: '$e');
    }
  }

  /// Chooses [font] for Pāli reading; null restores the built-in fonts.
  Future<void> select(DownloadableFont? font) async {
    try {
      await FontLibraryService.instance.select(font);
      state = state.copyWith(
        selectedId: font?.id,
        clearSelection: font == null,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  /// Deletes the downloaded file and clears the choice if it was selected.
  Future<void> remove(DownloadableFont font) async {
    try {
      await FontLibraryService.instance.remove(font);
      final installed = {...state.installed}..remove(font.id);
      final wasSelected = state.selectedId == font.id;
      state = state.copyWith(
        installed: installed,
        selectedId: wasSelected ? null : state.selectedId,
        clearSelection: wasSelected,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  void _emit() {
    if (_disposed) return;
    state = state.copyWith(progress: Map<String, double>.of(_progress));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final fontLibraryProvider =
    StateNotifierProvider<FontLibraryNotifier, FontLibraryState>(
      (ref) => FontLibraryNotifier(),
    );

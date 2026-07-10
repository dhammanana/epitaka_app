/// The status of the FTS index building process.
enum IndexStatus {
  /// FTS has not been checked yet.
  unknown,

  /// FTS index is ready (already built).
  ready,

  /// User needs to choose a translation language before building.
  needsTranslationChoice,

  /// Index is currently being built.
  building,

  /// Index building failed.
  error,
}

/// Detailed phases within the FTS index build process.
enum IndexBuildPhase {
  /// Loading translations into a lookup map.
  loadingTranslations,

  /// Indexing combined Pāli + translation rows into fts_index.
  indexingCombined;

  String get label {
    switch (this) {
      case IndexBuildPhase.loadingTranslations:
        return 'Loading translations…';
      case IndexBuildPhase.indexingCombined:
        return 'Indexing Pāli + translation…';
    }
  }

  /// Human-readable step number (e.g. "1/2").
  String get stepLabel {
    final steps = IndexBuildPhase.values.length;
    final idx = index + 1;
    return 'Step $idx/$steps';
  }
}

/// The state of the index controller with detailed progress info.
class IndexState {
  final IndexStatus status;
  final String? errorMessage;
  final int currentProgress;
  final int totalProgress;
  final String? indexedTranslationLang;
  final String? phaseLabel;
  final IndexBuildPhase? buildPhase;
  final int batchCurrent;
  final int batchTotal;
  final double itemsPerSecond;

  const IndexState({
    this.status = IndexStatus.unknown,
    this.errorMessage,
    this.currentProgress = 0,
    this.totalProgress = 0,
    this.indexedTranslationLang,
    this.phaseLabel,
    this.buildPhase,
    this.batchCurrent = 0,
    this.batchTotal = 0,
    this.itemsPerSecond = 0,
  });

  // ── Named constructors used by IndexController ────────────────────────

  /// Initial state before any check has been performed.
  const IndexState.unknown() : this();

  /// State while checking the index status.
  const IndexState.checking() : this(status: IndexStatus.unknown);

  /// State when the index is corrupted.
  const IndexState.corrupted(String message) : this(
    status: IndexStatus.error,
    errorMessage: message,
  );

  /// State when the index is ready and built.
  const IndexState.ready() : this(status: IndexStatus.ready);

  /// State when index building failed.
  const IndexState.failed(String message) : this(
    status: IndexStatus.error,
    errorMessage: message,
  );

  /// State while the index is being built with progress info.
  factory IndexState.building({double progress = 0, String status = ''}) {
    return IndexState(
      status: IndexStatus.building,
      currentProgress: (progress * 100).round(),
      totalProgress: 100,
      phaseLabel: status,
    );
  }

  /// Apply a progress snapshot to produce an updated state.
  IndexState withProgress(dynamic p) {
    final phase = p.phaseIndex >= 0 &&
            p.phaseIndex < IndexBuildPhase.values.length
        ? IndexBuildPhase.values[p.phaseIndex]
        : null;
    return copyWith(
      currentProgress: p.current,
      totalProgress: p.total,
      buildPhase: phase,
      phaseLabel: '${p.stepLabel}  ${p.phaseLabel}',
      batchCurrent: p.batchCurrent,
      batchTotal: p.batchTotal,
      itemsPerSecond: p.itemsPerSecond,
    );
  }

  IndexState copyWith({
    IndexStatus? status,
    String? errorMessage,
    int? currentProgress,
    int? totalProgress,
    String? indexedTranslationLang,
    String? phaseLabel,
    IndexBuildPhase? buildPhase,
    int? batchCurrent,
    int? batchTotal,
    double? itemsPerSecond,
    bool clearPhase = false,
    bool clearSpeed = false,
  }) {
    return IndexState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      currentProgress: currentProgress ?? this.currentProgress,
      totalProgress: totalProgress ?? this.totalProgress,
      indexedTranslationLang:
          indexedTranslationLang ?? this.indexedTranslationLang,
      phaseLabel: clearPhase ? null : (phaseLabel ?? this.phaseLabel),
      buildPhase: clearPhase ? null : (buildPhase ?? this.buildPhase),
      batchCurrent: batchCurrent ?? this.batchCurrent,
      batchTotal: batchTotal ?? this.batchTotal,
      itemsPerSecond: clearSpeed ? 0 : (itemsPerSecond ?? this.itemsPerSecond),
    );
  }

  double get progressFraction =>
      totalProgress > 0 ? currentProgress / totalProgress : 0.0;

  bool get isBuilt => status == IndexStatus.ready;
  bool get isBuilding => status == IndexStatus.building;
  bool get needsChoice => status == IndexStatus.needsTranslationChoice;
}

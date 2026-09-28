enum MdxStatus { pending, indexing, ready, error }

class MdxDictionaryInfo {
  final String id;
  final String title;
  final String? alias;
  final String mdxPath;
  final int userOrder;
  final bool enabled;
  final int entryCount;
  final String? indexPath;
  final String? lastError;
  final MdxStatus status;
  final double progress;
  final List<String> mddPaths;

  const MdxDictionaryInfo({
    required this.id,
    required this.title,
    this.alias,
    required this.mdxPath,
    required this.userOrder,
    required this.enabled,
    required this.entryCount,
    this.indexPath,
    this.lastError,
    this.status = MdxStatus.ready,
    this.progress = 1.0,
    this.mddPaths = const [],
  });

  String get displayTitle => alias?.isNotEmpty == true ? alias! : title;

  MdxDictionaryInfo copyWith({
    String? id,
    String? title,
    String? alias,
    bool clearAlias = false,
    int? userOrder,
    bool? enabled,
    int? entryCount,
    String? indexPath,
    String? lastError,
    bool clearError = false,
    MdxStatus? status,
    double? progress,
    List<String>? mddPaths,
  }) {
    return MdxDictionaryInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      alias: clearAlias ? null : (alias ?? this.alias),
      mdxPath: mdxPath,
      userOrder: userOrder ?? this.userOrder,
      enabled: enabled ?? this.enabled,
      entryCount: entryCount ?? this.entryCount,
      indexPath: indexPath ?? this.indexPath,
      lastError: clearError ? null : (lastError ?? this.lastError),
      status: status ?? this.status,
      progress: progress ?? this.progress,
      mddPaths: mddPaths ?? this.mddPaths,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'alias': alias,
    'mdxPath': mdxPath,
    'userOrder': userOrder,
    'enabled': enabled,
    'entryCount': entryCount,
    'indexPath': indexPath,
    'lastError': lastError,
    'status': status.name,
    'progress': progress,
    'mddPaths': mddPaths,
  };

  factory MdxDictionaryInfo.fromJson(Map<String, dynamic> j) {
    final entryCount = (j['entryCount'] as num?)?.toInt() ?? 0;
    final lastError = j['lastError'] as String?;
    final rawMdd = j['mddPaths'];
    return MdxDictionaryInfo(
      id: j['id'] as String,
      title: j['title'] as String,
      alias: j['alias'] as String?,
      mdxPath: j['mdxPath'] as String,
      userOrder: (j['userOrder'] as num).toInt(),
      enabled: j['enabled'] as bool,
      entryCount: entryCount,
      indexPath: j['indexPath'] as String?,
      lastError: lastError,
      status: _statusFromJson(j['status'], entryCount, lastError),
      progress: (j['progress'] as num?)?.toDouble() ?? 0.0,
      mddPaths: rawMdd is List
          ? [
              for (final e in rawMdd)
                if (e is String) e,
            ]
          : const [],
    );
  }

  static MdxStatus _statusFromJson(
    dynamic raw,
    int entryCount,
    String? lastError,
  ) {
    if (raw is String) {
      for (final s in MdxStatus.values) {
        if (s.name == raw) return s;
      }
    }
    if (lastError != null && lastError.isNotEmpty) return MdxStatus.error;
    if (entryCount == 0) return MdxStatus.indexing;
    return MdxStatus.ready;
  }
}

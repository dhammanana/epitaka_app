import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/responsive_breakpoint.dart';
import '../models/mdx_dictionary_info.dart';
import '../providers/mdx_dictionary_provider.dart';
import '../services/mdx_errors.dart';
import '../services/mdx_paths.dart';
import '../services/mdx_validate.dart';
import 'mdx_properties_sheet.dart';

class MdxSettingsSection extends ConsumerStatefulWidget {
  final ColorScheme colors;
  const MdxSettingsSection({super.key, required this.colors});

  @override
  ConsumerState<MdxSettingsSection> createState() => _MdxSettingsSectionState();
}

class _MdxSettingsSectionState extends ConsumerState<MdxSettingsSection> {
  bool _busy = false;
  String? _lastFolder;

  @override
  void initState() {
    super.initState();
    _loadLastFolder();
  }

  Future<void> _loadLastFolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastFolder = prefs.getString('mdx_last_folder');
    });
  }

  Future<void> _saveLastFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mdx_last_folder', path);
    setState(() {
      _lastFolder = path;
    });
  }

  Future<void> _runBusy(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(BuildContext context, int added, List<String> failures) {
    final msg = failures.isEmpty
        ? 'Added $added dictionary${added == 1 ? '' : 'ies'}.'
        : 'Added $added, failed ${failures.length}:\n${failures.take(3).join('\n')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _addOne(
    WidgetRef ref,
    String path,
    List<String> failures,
  ) async {
    try {
      await ref.read(mdxDictionariesProvider.notifier).addMdxFile(path);
    } on MdxException catch (e) {
      if (!e.message.contains('Already added')) failures.add(e.toString());
    } catch (e) {
      failures.add(describeMdxError(e, path: path));
    }
  }

  Future<void> _pickFiles(BuildContext context, WidgetRef ref) async {
    List<XFile> files;
    try {
      files = await openFiles(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'MDX', extensions: ['mdx']),
        ],
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open picker: ${describeMdxError(e)}'),
        ),
      );
      return;
    }
    if (files.isEmpty) return;
    var added = 0;
    final failures = <String>[];
    for (final f in files) {
      if (f.path.isEmpty) {
        failures.add('Picker returned an empty path (web/sandbox).');
        continue;
      }
      final before = ref.read(mdxDictionariesProvider).valueOrNull?.length ?? 0;
      await _addOne(ref, f.path, failures);
      final after = ref.read(mdxDictionariesProvider).valueOrNull?.length ?? 0;
      if (after > before) added++;
    }
    if (!context.mounted) return;
    _showResult(context, added, failures);
  }

  Future<MdxScanResult> _findMdxUnder(String dirPath) async {
    final mdx = <String>[];
    final candidates = <String>[];
    var filesSeen = 0;
    final extCounts = <String, int>{};
    var mddCount = 0;
    final dir = Directory(dirPath);
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        try {
          if (e is! File) continue;
          filesSeen++;
          final lower = e.path.toLowerCase();
          final dot = lower.lastIndexOf('.');
          final ext = dot >= 0 ? lower.substring(dot + 1) : '';
          extCounts[ext] = (extCounts[ext] ?? 0) + 1;
          if (lower.endsWith('.mdx')) {
            mdx.add(e.path);
          } else if (ext == 'mdd') {
            mddCount++;
          } else if (ext == 'bin' ||
              ext == 'mdict' ||
              ext == 'dict' ||
              ext.isEmpty) {
            if (candidates.length < 100) candidates.add(e.path);
          }
        } on FileSystemException {
          continue;
        }
      }
    } on FileSystemException catch (e) {
      throw MdxException('Cannot list folder: ${e.message}', path: dirPath);
    }
    mdx.sort();
    candidates.sort();
    return MdxScanResult(
      mdxPaths: mdx,
      filesSeen: filesSeen,
      extCounts: extCounts,
      mddCount: mddCount,
      misnamed: const [],
      candidates: candidates,
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    // Mobile (Android/iOS) has no direct folder access: the system file
    // picker (SAF / UIDocumentPicker) grants per-file access with NO
    // storage permission. The user multi-selects the whole dictionary
    // bundle (.mdx + .mdd/.css/.js) and each file is copied into app-private
    // storage. This keeps the app compliant with Google Play's All Files
    // Access policy (MANAGE_EXTERNAL_STORAGE is not declared).
    // Desktop keeps the native folder picker + recursive scan.
    if (Platform.isAndroid || Platform.isIOS) {
      final proceed = await _confirmMobileFolderHint(context);
      if (!proceed || !context.mounted) return;
      return _pickBundleFiles(context, ref);
    }
    String? dirPath;
    try {
      dirPath = await getDirectoryPath(confirmButtonText: 'Use folder');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open picker: ${describeMdxError(e)}'),
        ),
      );
      return;
    }
    if (dirPath == null) return;
    await _saveLastFolder(dirPath);
    if (!context.mounted) return;
    await _importScannedFolder(context, ref, dirPath);
  }

  Future<void> _importScannedFolder(
    BuildContext context,
    WidgetRef ref,
    String dirPath,
  ) async {
    MdxScanResult scan;
    try {
      scan = await _findMdxUnder(dirPath);
    } on MdxException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    final found = scan.mdxPaths.isNotEmpty ? scan.mdxPaths : scan.candidates;
    if (found.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(scan.describe(dirPath))));
      return;
    }
    var added = 0;
    final failures = <String>[];
    for (final p in found) {
      final before = ref.read(mdxDictionariesProvider).valueOrNull?.length ?? 0;
      await _addOne(ref, p, failures);
      final after = ref.read(mdxDictionariesProvider).valueOrNull?.length ?? 0;
      if (after > before) added++;
    }
    if (!context.mounted) return;
    _showResult(context, added, failures);
  }

  /// One-time hint for the mobile Folder button: the system picker can't
  /// grant a whole folder, so the user opens the folder and selects all
  /// files inside it. Shown once, then remembered.
  Future<bool> _confirmMobileFolderHint(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('mdx_folder_hint_seen') ?? false) return true;
    if (!context.mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import folder'),
        content: const Text(
          'Open the folder containing your dictionaries, select ALL files '
          'inside it (.mdx + .mdd/.css/.js), then confirm.\n\n'
          'Tip: use "Select all" in the picker menu to grab a folder with '
          'many dictionaries at once. Files are copied into the app — no '
          'storage permission needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open picker'),
          ),
        ],
      ),
    );
    if (proceed ?? false) {
      await prefs.setBool('mdx_folder_hint_seen', true);
      return true;
    }
    return false;
  }

  /// Mobile bundle import via the system multi-file picker (SAF on Android,
  /// UIDocumentPicker on iOS — the sandbox has no folder picker). Accepts
  /// the whole dictionary bundle — `.mdx` plus companion `.mdd` resources,
  /// `.css` stylesheets and `.js` — and copies the companions next to each
  /// persisted `.mdx` so images/audio/styling resolve. Needs NO storage
  /// permission: the picker grants per-file access and files are copied
  /// into app-private storage.
  Future<void> _pickBundleFiles(
    BuildContext context,
    WidgetRef ref,
  ) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        dialogTitle: 'Select all files in the dictionary folder',
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['mdx', 'mdd', 'css', 'js'],
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open picker: ${describeMdxError(e)}'),
        ),
      );
      return;
    }
    final paths = (result?.files ?? [])
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();
    if (paths.isEmpty) return;
    final mdxPaths = paths
        .where((p) => p.toLowerCase().endsWith('.mdx'))
        .toList();
    final companions = paths.where((p) {
      final lower = p.toLowerCase();
      if (lower.endsWith('.mdx')) return false;
      // Only real bundle sidecars — stray files from "Select all" are
      // ignored instead of being copied next to every dictionary.
      return lower.endsWith('.mdd') ||
          lower.endsWith('.css') ||
          lower.endsWith('.mcss') ||
          lower.endsWith('.js');
    }).toList();
    if (mdxPaths.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No .mdx file selected. Select the dictionary bundle '
            '(.mdx + .mdd/.css/.js) together.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }
    var added = 0;
    final failures = <String>[];
    for (final mdxSrc in mdxPaths) {
      // Resolve the persisted copy first so companions land next to it.
      String stable;
      try {
        stable = await ensurePersistentCopy(mdxSrc);
      } catch (e) {
        failures.add(describeMdxError(e, path: mdxSrc));
        continue;
      }
      for (final c in companions) {
        try {
          await copyCompanionNextToMdx(
            companionSrc: c,
            stableMdxPath: stable,
          );
        } catch (_) {
          // Non-fatal: the dictionary still imports, just without that file.
        }
      }
      final before = ref.read(mdxDictionariesProvider).valueOrNull?.length ?? 0;
      await _addOne(ref, mdxSrc, failures);
      final after = ref.read(mdxDictionariesProvider).valueOrNull?.length ?? 0;
      if (after > before) added++;
    }
    if (!context.mounted) return;
    _showResult(context, added, failures);
  }

  Future<void> _rescanFolder(BuildContext context, WidgetRef ref) async {
    if (_lastFolder == null) return;
    // Desktop-only: mobile imports are copied into app-private storage via
    // the system picker, so there is no external folder to rescan.
    if (Platform.isAndroid || Platform.isIOS) return;
    final dirPath = _lastFolder!;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder no longer exists: $dirPath')),
      );
      return;
    }
    await _runBusy(() async {
      MdxScanResult scan;
      try {
        scan = await _findMdxUnder(dirPath);
      } on MdxException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        return;
      }
      final found = scan.mdxPaths.isNotEmpty ? scan.mdxPaths : scan.candidates;
      final existingPaths = ref
          .read(mdxDictionariesProvider)
          .valueOrNull
          ?.map((d) => d.mdxPath)
          .toSet() ??
          {};
      var added = 0;
      var flagged = 0;
      final failures = <String>[];
      for (final p in found) {
        if (existingPaths.contains(p)) continue;
        final before = ref.read(mdxDictionariesProvider).valueOrNull?.length ?? 0;
        await _addOne(ref, p, failures);
        final after = ref.read(mdxDictionariesProvider).valueOrNull?.length ?? 0;
        if (after > before) added++;
      }
      final currentDicts = ref.read(mdxDictionariesProvider).valueOrNull ?? [];
      for (final d in currentDicts) {
        if (!found.contains(d.mdxPath) &&
            d.status != MdxStatus.error &&
            (d.lastError == null || !d.lastError!.startsWith('File not found'))) {
          await ref.read(mdxDictionariesProvider.notifier).update(
            d.id,
            (dict) => dict.copyWith(
              status: MdxStatus.error,
              lastError: 'File not found. It was moved or deleted.\n${d.mdxPath}',
            ),
          );
          flagged++;
        }
      }
      if (!context.mounted) return;
      _showResult(context, added, failures);
      if (flagged > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Flagged $flagged missing file(s) as "File not found"')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mdxDictionariesProvider);
    final isDesktop = ResponsiveBreakpoint.isDesktop(context);
    return Card(
      margin: EdgeInsets.only(top: isDesktop ? 16 : 8),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 12 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MDX dictionaries',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Beta feature — please send feedback if you spot mistakes.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 0,
              runSpacing: 0,
              children: [
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runBusy(() => _pickFiles(context, ref)),
                  icon: const Icon(Icons.file_open, size: 18),
                  label: const Text('Files'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runBusy(() => _pickFolder(context, ref)),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Folder'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                // Rescan only applies to desktop folder imports. Mobile
                // imports are copied into app-private storage, so there is
                // no external folder to rescan.
                if (_lastFolder != null &&
                    !Platform.isAndroid &&
                    !Platform.isIOS)
                  Tooltip(
                    message: 'Rescan $_lastFolder for new/removed MDX files',
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _runBusy(() => _rescanFolder(context, ref)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Rescan'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('Could not load MDX list: $e'),
              data: (dicts) {
                if (dicts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No MDX added. Pick .mdx files or a folder. Index builds once in the background, then search is instant.',
                    ),
                  );
                }
                final enabled = dicts.where((d) => d.enabled).toList();
                final disabled = dicts.where((d) => !d.enabled).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (enabled.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Enabled — drag the handle to re-arrange order',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        onReorderItem: (oldI, newI) {
                          final ids = enabled.map((d) => d.id).toList();
                          final item = ids.removeAt(oldI);
                          ids.insert(newI, item);
                          ids.addAll(disabled.map((d) => d.id));
                          ref
                              .read(mdxDictionariesProvider.notifier)
                              .reorder(ids);
                        },
                        children: [
                          for (var i = 0; i < enabled.length; i++)
                            _tile(
                              context,
                              ref,
                              enabled[i],
                              true,
                              i,
                              key: ValueKey('mdx-enabled-${enabled[i].id}'),
                            ),
                        ],
                      ),
                    ],
                    if (disabled.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Disabled',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      for (final d in disabled)
                        _tile(
                          context,
                          ref,
                          d,
                          false,
                          0,
                          key: ValueKey('mdx-disabled-${d.id}'),
                        ),
                    ],
                    _DiagnosticsFooter(dicts: dicts),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    MdxDictionaryInfo info,
    bool enabled,
    int index, {
    required Key key,
  }) {
    final id = info.id;
    final title = info.displayTitle;
    final lastError = info.lastError;
    final indexing =
        info.status == MdxStatus.pending || info.status == MdxStatus.indexing;
    final isError = info.status == MdxStatus.error;
    String subtitleText;
    switch (info.status) {
      case MdxStatus.pending:
        subtitleText = 'Queued for indexing…';
      case MdxStatus.indexing:
        subtitleText = info.progress > 0
            ? 'Indexing ${(info.progress * 100).round()}%…'
            : 'Indexing in background…';
      case MdxStatus.ready:
        subtitleText = '${info.entryCount} entries';
      case MdxStatus.error:
        subtitleText = lastError ?? 'Index failed';
    }
    return ListTile(
      key: key,
      leading: enabled
          ? ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            )
          : const Icon(Icons.book_outlined),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: isError
          ? Text(
              subtitleText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          : Text(subtitleText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (indexing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (isError)
            Icon(
              Icons.error_outline,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) async {
              switch (value) {
                case 'info':
                  MdxPropertiesSheet.show(context, id);
                case 'toggle':
                  await ref
                      .read(mdxDictionariesProvider.notifier)
                      .toggleEnabled(id, !enabled);
                case 'rebuild':
                  try {
                    await ref
                        .read(mdxDictionariesProvider.notifier)
                        .rebuild(id);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(describeMdxError(e))),
                    );
                  }
                case 'remove':
                  await ref
                      .read(mdxDictionariesProvider.notifier)
                      .remove(id);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info_outline, size: 20),
                  title: Text('Properties'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(
                    enabled
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 20,
                  ),
                  title: Text(enabled ? 'Disable' : 'Enable'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'rebuild',
                child: ListTile(
                  leading: Icon(Icons.refresh, size: 20),
                  title: Text('Rebuild index'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, size: 20),
                  title: Text('Remove'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsFooter extends ConsumerWidget {
  final List<MdxDictionaryInfo> dicts;
  const _DiagnosticsFooter({required this.dicts});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _openIndexFolder(BuildContext context) async {
    try {
      final indexDir = await mdxIndexDir();
      final uri = Uri.file(indexDir.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final totalIndexSizeFuture = ref.watch(mdxDictionariesProvider.notifier).getTotalIndexDirSize();
    final errorCount = dicts.where((d) => d.status == MdxStatus.error).length;

    return FutureBuilder<int>(
      future: totalIndexSizeFuture,
      builder: (context, snapshot) {
        final totalIndexSize = snapshot.data ?? 0;
        return Column(
          children: [
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${dicts.length} dictionaries, ${_formatBytes(totalIndexSize)} index',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open index folder'),
                    onPressed: () => _openIndexFolder(context),
                  ),
                  if (errorCount > 0) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.cleaning_services, size: 16),
                      label: Text('Clear errors ($errorCount)'),
                      onPressed: () => ref.read(mdxDictionariesProvider.notifier).clearErrorsAndRebuildAll(),
                      style: TextButton.styleFrom(foregroundColor: colors.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

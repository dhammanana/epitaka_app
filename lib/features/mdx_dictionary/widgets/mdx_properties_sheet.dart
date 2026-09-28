import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dict_reader/dict_reader.dart';

import '../models/mdx_dictionary_info.dart';
import '../providers/mdx_dictionary_provider.dart';
import '../services/mdx_paths.dart';

class MdxPropertiesSheet extends ConsumerStatefulWidget {
  final String dictId;
  const MdxPropertiesSheet({super.key, required this.dictId});

  static Future<void> show(BuildContext context, String dictId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MdxPropertiesSheet(dictId: dictId),
    );
  }

  @override
  ConsumerState<MdxPropertiesSheet> createState() => _MdxPropertiesSheetState();
}

class _MdxPropertiesSheetState extends ConsumerState<MdxPropertiesSheet> {
  int? _mdxFileSize;
  int? _indexSize;
  String? _headerTitle;
  String? _headerDescription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final dicts = ref.read(mdxDictionariesProvider).valueOrNull;
    final dict = dicts?.where((d) => d.id == widget.dictId).firstOrNull;
    if (dict == null) return;

    int? mdxSize;
    try {
      final file = File(dict.mdxPath);
      if (await file.exists()) {
        mdxSize = await file.length();
      }
    } catch (_) {}

    int? idxSize;
    if (dict.indexPath != null) {
      idxSize = await ref.read(mdxDictionariesProvider.notifier).getIndexSize(dict.indexPath!);
    }

    String? title;
    String? description;
    try {
      final reader = DictReader(dict.mdxPath);
      await reader.initDict(readKeys: false, readRecordBlockInfo: false);
      title = reader.header['Title'];
      description = reader.header['Description'];
      await reader.close();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _mdxFileSize = mdxSize;
        _indexSize = idxSize;
        _headerTitle = title;
        _headerDescription = description;
        _loading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _openIndexFolder() async {
    try {
      final indexDir = await mdxIndexDir();
      final uri = Uri.file(indexDir.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _renameAlias(BuildContext context, MdxDictionaryInfo dict) async {
    final controller = TextEditingController(text: dict.alias ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename dictionary'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Custom name (alias)',
            hintText: 'Leave empty to use original title',
          ),
          autofocus: true,
          maxLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await ref.read(mdxDictionariesProvider.notifier).updateTitle(widget.dictId, result);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dicts = ref.watch(mdxDictionariesProvider);
    return dicts.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 200,
        child: Center(child: Text('Error: $e')),
      ),
      data: (list) {
        final dict = list.where((d) => d.id == widget.dictId).firstOrNull;
        if (dict == null) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('Dictionary not found')),
          );
        }

        final colors = Theme.of(context).colorScheme;
        final displayTitle = dict.displayTitle;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: 'Path', value: dict.mdxPath, selectable: true),
                        if (dict.alias != null)
                          _DetailRow(label: 'Original title', value: dict.title),
                        if (_headerTitle != null && _headerTitle != dict.title)
                          _DetailRow(label: 'MDX header Title', value: _headerTitle!),
                        if (_headerDescription != null && _headerDescription!.isNotEmpty)
                          _DetailRow(label: 'Description', value: _headerDescription!),
                        const Divider(),
                        _DetailRow(
                          label: 'MDX file size',
                          value: _mdxFileSize != null ? _formatBytes(_mdxFileSize!) : (_loading ? '…' : 'Unknown'),
                        ),
                        _DetailRow(
                          label: 'Index size',
                          value: _indexSize != null ? _formatBytes(_indexSize!) : (_loading ? '…' : 'No index'),
                        ),
                        _DetailRow(
                          label: 'Entries',
                          value: dict.entryCount > 0 ? dict.entryCount.toString() : (_loading ? '…' : 'Not indexed'),
                        ),
                        _DetailRow(
                          label: 'Status',
                          value: _statusLabel(dict.status, dict.lastError),
                          valueStyle: TextStyle(
                            color: dict.status == MdxStatus.error
                                ? colors.error
                                : dict.status == MdxStatus.ready
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                          ),
                        ),
                        if (dict.lastError != null && dict.lastError!.isNotEmpty) ...[
                          const Divider(),
                          Text('Last error', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          SelectableText(dict.lastError!, style: TextStyle(color: colors.error, fontSize: 12)),
                        ],
                        if (dict.mddPaths.isNotEmpty) ...[
                          const Divider(),
                          Text('MDD files', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          ...dict.mddPaths.map((mdd) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SelectableText(mdd, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                          )),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Open index folder'),
                      onPressed: _openIndexFolder,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Rename'),
                      onPressed: () => _renameAlias(context, dict),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(MdxStatus status, String? error) {
    switch (status) {
      case MdxStatus.pending:
        return 'Pending';
      case MdxStatus.indexing:
        return 'Indexing…';
      case MdxStatus.ready:
        return 'Ready';
      case MdxStatus.error:
        return 'Error: ${error ?? 'Unknown'}';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.label,
    required this.value,
    this.selectable = false,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 2),
          selectable
              ? SelectableText(value, style: valueStyle ?? Theme.of(context).textTheme.bodyMedium)
              : Text(value, style: valueStyle ?? Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
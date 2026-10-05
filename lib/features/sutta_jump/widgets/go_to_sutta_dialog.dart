import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/utils/app_navigation.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../services/sutta_code_service.dart';

bool _dialogOpen = false;

/// Opens the "Go to sutta" box. A second call while it is open does nothing.
Future<void> showGoToSuttaDialog(BuildContext context) async {
  if (_dialogOpen) return;
  // Callers such as the phone side menu are gone once the dialog closes, so
  // everything after it runs on the root navigator's context.
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  _dialogOpen = true;
  SuttaTarget? target;
  try {
    target = await showDialog<SuttaTarget>(
      context: rootContext,
      builder: (_) => Dialog(
        // Top of the screen, so a phone keyboard does not cover the list.
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const GoToSuttaDialog(),
        ),
      ),
    );
  } finally {
    _dialogOpen = false;
  }
  if (target == null || !rootContext.mounted) return;

  final container = ProviderScope.containerOf(rootContext, listen: false);
  final bookName = await _bookNameFor(container, target.bookId);
  if (!rootContext.mounted) return;
  container
      .read(readerTabsProvider.notifier)
      .openTab(
        ReaderTabInfo(
          bookId: target.bookId,
          bookName: bookName,
          initialParaId: target.paraId,
        ),
      );
  openReaderRoute(rootContext);
}

Future<String> _bookNameFor(ProviderContainer container, String bookId) async {
  try {
    final db = await container.read(epitakaDbProvider.future);
    final rows = await (db.select(db.books)
          ..where((b) => b.bookId.equals(bookId))
          ..limit(1))
        .get();
    final name = rows.isNotEmpty ? rows.first.bookName : null;
    if (name != null && name.isNotEmpty) return name;
  } catch (e) {
    developer.log(
      '[GO TO SUTTA] Book name lookup failed for $bookId: $e',
      name: 'epitaka.sutta_jump',
    );
  }
  return bookId;
}

/// The text field and live match list. Pops with the chosen [SuttaTarget].
class GoToSuttaDialog extends ConsumerStatefulWidget {
  const GoToSuttaDialog({super.key});

  @override
  ConsumerState<GoToSuttaDialog> createState() => _GoToSuttaDialogState();
}

// ListTile's dense height; a fixed extent lets the arrow keys scroll the
// highlighted line into view without measuring rows.
const _rowHeight = 48.0;

class _GoToSuttaDialogState extends ConsumerState<GoToSuttaDialog> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<SuttaTarget> _results = const [];
  // The text [_results] belong to, so "No sutta" waits for the lookup.
  String _resultsFor = '';
  bool _failed = false;
  int _highlight = 0;
  // The headings lookup loads once on first input; keystrokes after that
  // filter the cached rows synchronously. Only the newest load may write
  // the list.
  Future<SuttaLookupCache>? _lookupFuture;
  int _query = 0;
  // A second Enter during the closing animation would pop the page below.
  bool _closing = false;

  Future<SuttaLookupCache> _lookup() async {
    final cached = _lookupFuture;
    if (cached != null) return cached;
    final loading = _loadLookup();
    _lookupFuture = loading;
    return loading;
  }

  Future<SuttaLookupCache> _loadLookup() async {
    final db = await ref.read(epitakaDbProvider.future);
    return loadSuttaLookup(db);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _update(String text) async {
    final query = ++_query;
    var results = const <SuttaTarget>[];
    var failed = false;
    try {
      final cache = await _lookup();
      // Codes first (`mn10`); sutta and book names when no code matches.
      results = searchSuttaCodes(cache, text);
      if (results.isEmpty && text.trim().isNotEmpty) {
        results = searchSuttaNames(cache, text);
      }
    } catch (e) {
      developer.log(
        '[GO TO SUTTA] Lookup failed for "$text": $e',
        name: 'epitaka.sutta_jump',
      );
      failed = true;
    }
    if (!mounted || query != _query) return;
    setState(() {
      _results = results;
      _resultsFor = text;
      _failed = failed;
      _highlight = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(SuttaTarget target) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(target);
  }

  void _moveHighlight(int index) {
    setState(() => _highlight = index);
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final top = index * _rowHeight;
    if (top < position.pixels) {
      _scroll.jumpTo(top);
    } else if (top + _rowHeight > position.pixels + position.viewportDimension) {
      _scroll.jumpTo(top + _rowHeight - position.viewportDimension);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_results.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveHighlight((_highlight + 1) % _results.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveHighlight((_highlight - 1 + _results.length) % _results.length);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = _controller.text;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            onKeyEvent: _onKey,
            child: TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                labelText: l10n.goToSutta,
                hintText: l10n.goToSuttaHint,
                prefixIcon: const Icon(Icons.near_me_outlined),
              ),
              onChanged: _update,
              onSubmitted: (_) {
                if (_results.isNotEmpty) _open(_results[_highlight]);
              },
            ),
          ),
          if (_failed && _resultsFor == text)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.suttaLookupFailed,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else if (text.trim().isNotEmpty &&
              _results.isEmpty &&
              _resultsFor == text)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.noSuttaFound(text.trim()),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          if (_results.isNotEmpty)
            Flexible(
              child: ListView.builder(
                controller: _scroll,
                shrinkWrap: true,
                itemExtent: _rowHeight,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final target = _results[index];
                  return ListTile(
                    dense: true,
                    selected: index == _highlight,
                    selectedTileColor: theme.colorScheme.primaryContainer,
                    title: Row(
                      children: [
                        Text('${target.label} · '),
                        Expanded(
                          child: PaliText(
                            target.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _open(target),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

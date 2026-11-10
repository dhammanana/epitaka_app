import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/utils/app_navigation.dart';
import '../../../shared/widgets/history_list.dart';
import '../../../shared/widgets/history_nav.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../shared/widgets/search_box_actions.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../../search/services/regex_search.dart';
import '../providers/sutta_history_provider.dart';
import '../services/sutta_code_service.dart';

/// Whether "Go to sutta" takes a regex over sutta names (spec G). Session
/// only, like the other rx flags: never saved, so the box always opens in
/// normal mode after a restart.
final goToSuttaRegexProvider = StateProvider<bool>((ref) => false);

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
  container.read(suttaHistoryProvider.notifier).add(encodeSutta(target));
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
  // Why the pattern does not compile, when rx is on and it does not.
  String? _patternError;
  // The pattern ran past its time limit (spec K).
  bool _patternTooSlow = false;
  // The running rx name search; the next keystroke and closing cancel it.
  RegexJob<Object?>? _regexJob;
  // A second Enter during the closing animation would pop the page below.
  bool _closing = false;

  // The suttas opened before show as rows while the box is empty. The box
  // keeps the cursor; the arrows move a highlight over the rows.
  late final HistoryNav _nav = HistoryNav(
    onChanged: () {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _nav.scrollTo(_scroll),
      );
    },
    onActivate: (i) {
      final history = _historyTargets();
      if (i < history.length) _open(history[i]);
    },
  );

  List<SuttaTarget> _historyTargets() => [
    for (final s in ref.read(suttaHistoryProvider))
      ?decodeSutta(s),
  ];

  bool get _showRows =>
      _controller.text.isEmpty && ref.read(suttaHistoryProvider).isNotEmpty;

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
    _regexJob?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _update(String text) async {
    final query = ++_query;
    _regexJob?.cancel();
    final regexOn = ref.read(goToSuttaRegexProvider);
    var results = const <SuttaTarget>[];
    var failed = false;
    String? patternError;
    var tooSlow = false;
    try {
      final cache = await _lookup();
      // Keystrokes made while the list loaded: only the newest starts a job.
      if (!mounted || query != _query) return;
      if (regexOn) {
        // Regex over sutta and book names only (spec G); codes are exact.
        if (text.isNotEmpty) {
          final error = regexError(text);
          if (error != null) {
            patternError = error;
          } else {
            results = await searchSuttaNamesRegex(
              cache,
              text,
              onJob: (job) => _regexJob = job,
            );
          }
        }
      } else {
        // Codes first (`mn10`); sutta and book names when no code matches.
        results = searchSuttaCodes(cache, text);
        if (results.isEmpty && text.trim().isNotEmpty) {
          results = searchSuttaNames(cache, text);
        }
      }
    } on RegexTooSlow {
      tooSlow = true;
    } on RegexCancelled {
      return; // a newer keystroke, or the dialog closed
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
      _patternError = patternError;
      _patternTooSlow = tooSlow;
      _highlight = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleRegex() {
    final notifier = ref.read(goToSuttaRegexProvider.notifier);
    notifier.state = !notifier.state;
    // The box text means something else in the other mode; re-run it.
    _update(_controller.text);
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
    if (_showRows) {
      final r = _nav.handle(event, _historyTargets().length);
      if (r != KeyEventResult.ignored) return r;
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
    final regexOn = ref.watch(goToSuttaRegexProvider);
    final historyTargets = [
      for (final s in ref.watch(suttaHistoryProvider))
        ?decodeSutta(s),
    ];
    _nav.clamp(historyTargets.length);
    final showRows = text.isEmpty && historyTargets.isNotEmpty;
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
              // `.m`, `.t`, `.n` are regex: rx keeps them as typed.
              inputFormatters: regexOn
                  ? const []
                  : const [VelthuisInputFormatter()],
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                labelText: l10n.goToSutta,
                hintText: l10n.goToSuttaHint,
                prefixIcon: const Icon(Icons.near_me_outlined),
                suffixIcon: SearchBoxSuffixActions(
                  showClear: _controller.text.isNotEmpty,
                  onClear: () {
                    _controller.clear();
                    _nav.reset();
                    // The rows show now, not after the lookup.
                    setState(() {});
                    _update('');
                  },
                  regexOn: regexOn,
                  onToggleRegex: _toggleRegex,
                ),
                errorText: _resultsFor != text
                    ? null
                    : _patternTooSlow
                    ? l10n.patternTooSlow
                    : _patternError != null
                    ? l10n.invalidPattern(_patternError!)
                    : null,
              ),
              onChanged: (t) {
                if (t.isNotEmpty) _nav.reset();
                // The rows hide and show with the text, not after the lookup.
                setState(() {});
                _update(t);
              },
              onSubmitted: (_) {
                // The key handler already opened a highlighted history row.
                if (_nav.index >= 0 && _showRows) return;
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
              _resultsFor == text &&
              // An invalid pattern already says so at the field.
              _patternError == null &&
              !_patternTooSlow)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.noSuttaFound(text.trim()),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          if (showRows)
            Flexible(
              child: HistoryList(
                title: l10n.recentSuttas,
                onClear: ref.read(suttaHistoryProvider.notifier).clear,
                controller: _scroll,
                selectedIndex: _nav.index < 0 ? null : _nav.index,
                items: [
                  for (final t in historyTargets)
                    HistoryItem(
                      key: '${t.bookId}|${t.paraId}',
                      title: PaliText(
                        t.title,
                        style: historyTitleStyle(theme.colorScheme),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(t.label),
                      onTap: () => _open(t),
                      onDelete: () => ref
                          .read(suttaHistoryProvider.notifier)
                          .remove(encodeSutta(t)),
                    ),
                ],
              ),
            ),
          if (_results.isNotEmpty && !showRows)
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

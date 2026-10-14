import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/dictionary_books_provider.dart';
import '../../mdx_dictionary/models/mdx_dictionary_info.dart';
import '../../mdx_dictionary/providers/mdx_dictionary_provider.dart';
import '../database/dpd_database.dart';
import 'dpd_database_provider.dart';

/// `dictionary_books.id` of the old single DPD block. The DPD sources below
/// replace it.
const kDpdBookId = 11;

/// ePitaka's own PTS, Concise, PEA and DPPN. DPD supersedes them, so they are
/// never listed or looked up. The rows stay in `epitaka.db`.
const kHiddenDictionaryBookIds = {5, 6, 8, 9};

class DpdSourceMeta {
  final String id;
  final String label;
  const DpdSourceMeta(this.id, this.label);
}

/// The summary at the top of the page. Not a part of the lookup itself: the
/// page builder draws it from the other items.
const kDpdSummaryId = 'dpd_summary';

/// The parts of a DPD lookup that can be ordered and switched on their own,
/// in the DPD app's default order.
const kDpdSources = [
  DpdSourceMeta(kDpdSummaryId, 'DPD Summary'),
  DpdSourceMeta('dpd_headwords', 'DPD Headwords'),
  DpdSourceMeta('dpd_roots', 'DPD Roots'),
  DpdSourceMeta('dpd_abbreviations', 'DPD Abbreviations'),
  DpdSourceMeta('dpd_deconstructor', 'DPD Deconstructor'),
  DpdSourceMeta('dpd_grammar', 'DPD Grammar'),
  DpdSourceMeta('dpd_help', 'DPD Help'),
  DpdSourceMeta('dpd_epd', 'DPD EPD'),
  DpdSourceMeta('dpd_variants', 'DPD Variants'),
  DpdSourceMeta('dpd_spelling', 'DPD Spelling'),
  DpdSourceMeta('dpd_see', 'DPD See'),
  DpdSourceMeta('dpd_abbreviations_other', 'DPD Other Abbreviations'),
];

enum DictionaryItemKind { dpdSource, external, book, mdx }

String bookItemId(int bookId) => 'book_$bookId';
String mdxItemId(String mdxId) => 'mdx_$mdxId';

/// One row of the ordered dictionary list.
class DictionaryListItem {
  const DictionaryListItem({
    required this.id,
    required this.label,
    required this.kind,
    this.enabledOverride,
    this.ready = true,
  });

  /// `dpd_*` for a DPD source, the raw `dict_meta.dict_id` for an external
  /// dictionary, `book_<id>` for an ePitaka book and `mdx_<id>` for an MDX
  /// dictionary.
  final String id;
  final String label;
  final DictionaryItemKind kind;

  /// An MDX dictionary keeps its own on/off flag, which other code reads.
  final bool? enabledOverride;

  /// False for an MDX file that is still indexing or failed: it is listed in
  /// the settings but gives no results yet.
  final bool ready;
}

class DictionaryListEntry {
  const DictionaryListEntry(this.item, this.enabled);
  final DictionaryListItem item;
  final bool enabled;
}

/// What is saved: the user's order and the items they switched off. Only the
/// off items are stored, so a dictionary seen for the first time shows up on.
class StoredDictionaryList {
  const StoredDictionaryList({this.order = const [], this.disabled = const {}});

  final List<String> order;
  final Set<String> disabled;

  Map<String, dynamic> toJson() => {
    'order': order,
    'disabled': disabled.toList(),
  };

  factory StoredDictionaryList.fromJson(Map<String, dynamic> json) =>
      StoredDictionaryList(
        // Copied, not cast lazily, so a value of the wrong type throws here,
        // inside the load's error guard, not later when the list is merged.
        order: List<String>.from(json['order'] as List),
        disabled: Set<String>.from(json['disabled'] as List),
      );
}

/// The saved order, cut down to what is installed, with anything new added at
/// the end. Ids that are saved but not installed right now (DPD missing, an
/// MDX file removed) stay out of the result and out of the way: the saved
/// list keeps them, so they return to their place when they come back.
List<DictionaryListEntry> mergeDictionaryList({
  required List<String> savedOrder,
  required Set<String> disabled,
  required List<DictionaryListItem> available,
}) {
  final byId = {for (final item in available) item.id: item};
  final shown = <String>[];
  final seen = <String>{};
  for (final id in savedOrder) {
    if (byId.containsKey(id) && seen.add(id)) shown.add(id);
  }
  for (final item in available) {
    if (!seen.add(item.id)) continue;
    // A summary that is new to a saved list goes before the first DPD source,
    // where it sits by default, and not at the end with the other new items.
    if (item.id == kDpdSummaryId) {
      final firstDpd = shown.indexWhere(
        (id) => byId[id]!.kind == DictionaryItemKind.dpdSource,
      );
      shown.insert(firstDpd < 0 ? 0 : firstDpd, item.id);
    } else {
      shown.add(item.id);
    }
  }
  return [
    for (final id in shown)
      DictionaryListEntry(
        byId[id]!,
        byId[id]!.enabledOverride ?? !disabled.contains(id),
      ),
  ];
}

/// The saved list that matches the old `dictionary_books` order and switches.
/// The old DPD block (id 11) becomes the DPD sources, in their default order,
/// all on or all off with it. The dropped books go. DPD's external
/// dictionaries had no place before, so they join at the end when first seen.
StoredDictionaryList migrateOldBookOrder(List<DictionaryBook> books) {
  final sorted = [...books]..sort((a, b) => a.userOrder.compareTo(b.userOrder));
  final order = <String>[];
  final disabled = <String>{};
  for (final b in sorted) {
    if (kHiddenDictionaryBookIds.contains(b.id)) continue;
    final ids = b.id == kDpdBookId
        ? [for (final s in kDpdSources) s.id]
        : [bookItemId(b.id)];
    order.addAll(ids);
    if (!b.userChoice) disabled.addAll(ids);
  }
  return StoredDictionaryList(order: order, disabled: disabled);
}

const dictionaryListPrefsKey = 'dictionary_list';

final dictionaryListStoreProvider =
    StateNotifierProvider<DictionaryListStore, StoredDictionaryList?>(
      DictionaryListStore.new,
    );

/// Holds the saved list in SharedPreferences. `null` while it loads.
class DictionaryListStore extends StateNotifier<StoredDictionaryList?> {
  DictionaryListStore(this._ref) : super(null) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    var stored = const StoredDictionaryList();
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(dictionaryListPrefsKey);
      if (json != null) {
        stored = StoredDictionaryList.fromJson(jsonDecode(json));
      } else {
        stored = await _migrateOldBooks(prefs) ?? stored;
      }
    } on Object catch (e) {
      // Damaged prefs, or a value of the wrong shape: start from the defaults.
      // Left uncaught, the state stays null and the lookup page never loads.
      debugPrint('[DPD] dictionary list not read: $e');
    }
    if (mounted) state = stored;
  }

  /// Carries the order and switches from `dictionary_books` in `epitaka.db`
  /// into the saved list. The saved list is what stops a second run: it is
  /// written only after the books were read, so a failed read tries again at
  /// the next launch. `epitaka.db` is read here and never written.
  Future<StoredDictionaryList?> _migrateOldBooks(SharedPreferences prefs) async {
    final List<DictionaryBook> books;
    try {
      books = await _ref.read(dictionaryBooksProvider.future);
    } catch (e) {
      debugPrint('[DPD] dictionary order not migrated: $e');
      return null;
    }
    final migrated = migrateOldBookOrder(books);
    await prefs.setString(dictionaryListPrefsKey, jsonEncode(migrated.toJson()));
    return migrated;
  }

  Future<void> _save(StoredDictionaryList next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dictionaryListPrefsKey, jsonEncode(next.toJson()));
  }

  /// Saves the order the user sees. Saved ids that are not shown now go to the
  /// end, so they keep a place for later.
  Future<void> setOrder(List<String> shownOrder) async {
    final current = state ?? const StoredDictionaryList();
    final hidden = current.order.where((id) => !shownOrder.contains(id));
    await _save(
      StoredDictionaryList(
        order: [...shownOrder, ...hidden],
        disabled: current.disabled,
      ),
    );
    final mdxIds = [
      for (final id in shownOrder)
        if (id.startsWith('mdx_')) id.substring(4),
    ];
    if (mdxIds.isNotEmpty) {
      await _ref.read(mdxDictionariesProvider.notifier).reorder(mdxIds);
    }
  }

  Future<void> setEnabled(DictionaryListItem item, bool enabled) async {
    if (item.kind == DictionaryItemKind.mdx) {
      await _ref
          .read(mdxDictionariesProvider.notifier)
          .toggleEnabled(item.id.substring(4), enabled);
      return;
    }
    final current = state ?? const StoredDictionaryList();
    final disabled = {...current.disabled};
    if (enabled) {
      disabled.remove(item.id);
    } else {
      disabled.add(item.id);
    }
    await _save(StoredDictionaryList(order: current.order, disabled: disabled));
  }
}

/// Every dictionary the app can show right now, in the default order: DPD
/// sources, DPD's external dictionaries, ePitaka's kept books, MDX files.
final dictionaryAvailableProvider = FutureProvider<List<DictionaryListItem>>((
  ref,
) async {
  final items = <DictionaryListItem>[
    for (final s in kDpdSources)
      DictionaryListItem(
        id: s.id,
        label: s.label,
        kind: DictionaryItemKind.dpdSource,
      ),
  ];

  try {
    final dao = await ref.watch(dpdDaoProvider.future);
    final List<DictMetaData> meta = await dao.getAllDictMeta();
    for (final m in meta) {
      items.add(
        DictionaryListItem(
          id: m.dictId,
          label: m.name,
          kind: DictionaryItemKind.external,
        ),
      );
    }
  } on DpdUnavailable {
    // No DPD file: its external dictionaries are not there to list.
  }

  final books = await ref.watch(dictionaryBooksProvider.future);
  for (final b in books) {
    if (b.id == kDpdBookId || kHiddenDictionaryBookIds.contains(b.id)) continue;
    items.add(
      DictionaryListItem(
        id: bookItemId(b.id),
        label: b.name,
        kind: DictionaryItemKind.book,
      ),
    );
  }

  for (final d in ref.watch(mdxDictionariesProvider).valueOrNull ?? const []) {
    items.add(
      DictionaryListItem(
        id: mdxItemId(d.id),
        label: d.displayTitle,
        kind: DictionaryItemKind.mdx,
        enabledOverride: d.enabled,
        ready: d.status == MdxStatus.ready,
      ),
    );
  }
  return items;
});

/// The list the settings page shows and the lookup page follows.
final dictionaryListProvider =
    Provider<AsyncValue<List<DictionaryListEntry>>>((ref) {
      final stored = ref.watch(dictionaryListStoreProvider);
      final available = ref.watch(dictionaryAvailableProvider);
      if (stored == null) return const AsyncLoading();
      return available.whenData(
        (items) => mergeDictionaryList(
          savedOrder: stored.order,
          disabled: stored.disabled,
          available: items,
        ),
      );
    });

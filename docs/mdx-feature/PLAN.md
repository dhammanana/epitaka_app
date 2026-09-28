# MDX Dictionary Support — Plan (feature/mdx-dictionary-support)

Upstream reference: https://github.com/mumu-lhl/Ciyue (MIT) + dict_reader (MIT, git dep).
We use dict_reader as a dependency, we do NOT copy its files. Our code is original.

## Why this layout merges cleanly
- All new code lives in `lib/features/mdx_dictionary/` (additive only).
- Existing files untouched until final integration (2 small edits):
  1. `lib/features/settings/screens/dictionary_settings_screen.dart` → add `MdxSettingsSection()`
  2. `lib/features/dictionary/widgets/dictionary_sheet.dart` + `dictionary_panel.dart` → add `MdxDefinitionSection()`
- No Drift migration on `epitaka.db` (shipped asset). MDX meta lives in SharedPreferences JSON;
  per-dict index is a sidecar SQLite `<mdx>.idx.sqlite` in app-support dir → delete = uninstall.

## Performance design (1M-entry synonym dict)
1. Import runs once in `Isolate.run`: dict_reader walks keys → batch-insert (5000/txn)
   into sidecar `mdx_index(key, norm_key, block_id, start, end)` + `CREATE INDEX idx_norm(norm_key)`.
   Progress via SendPort; UI never blocks; `wakelock_plus` on.
2. Search = SQL `WHERE norm_key GLOB 'q*' LIMIT 25` (~0.1ms), never loads key list to RAM.
   Exact lookup decodes only the hit record blocks on demand (LRU 8 blocks).
3. Display = `flutter_html` (no WebView/JS). Strip `<script>`, ignore external CSS/JS by default;
   optional "rich mode" later behind a flag after measuring. Sections are `AutomaticKeepAlives`
   + `family` providers with `keepAlive` so scroll/typing never re-renders HTML.

## Copyright rule
- `pubspec.yaml` will add `dict_reader: git: url: https://github.com/mumu-lhl/dict_reader.git`.
- Our parser/index/render files are written from the format spec, not pasted from Ciyue.
- Keep `LICENSE` attribution line for MIT deps.

## Steps
1. [x] Branch + scaffold (this commit, no existing edits)
2. Add deps (`dict_reader`, `file_picker`), `MdxIndexService` (isolate + sidecar sqlite)
3. `MdxDictionaryProvider` (meta JSON + order/enable, mirrors DictionaryBooksNotifier API)
4. `MdxSettingsSection` (pick files/folder via file_selector/file_picker, progress, reorder/remove)
5. `MdxDefinitionSection` (prefix search + exact HTML via flutter_html, keep-alive)
6. Perf test with 1M synonym MDX: measure index time, search ms, sheet open ms, scroll jank
7. Wire the 2 integration edits, `flutter analyze`, merge `main` → PR.

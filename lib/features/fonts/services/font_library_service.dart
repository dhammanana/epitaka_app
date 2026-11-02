import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/pali_text_utils.dart' show setDownloadedPaliFonts;
import '../models/downloadable_font.dart';

/// What [FontLibraryService.restore] found on disk.
class FontLibrarySnapshot {
  final List<DownloadableFont> catalog;
  final Set<String> installed;
  final String? selectedId;

  const FontLibrarySnapshot({
    required this.catalog,
    required this.installed,
    required this.selectedId,
  });

  DownloadableFont? get selected {
    for (final font in catalog) {
      if (font.id == selectedId) return font;
    }
    return null;
  }
}

/// Downloads Google Fonts into the app, registers them with the engine and
/// remembers which one is used for Pāli reading.
///
/// Fonts live in `<app support>/fonts/<id>.ttf`. Registration uses
/// `FontLoader`, which works at runtime and needs no asset rebuild; a font
/// registered in a session stays available until the process ends, so
/// [restore] re-registers the installed set on every launch.
class FontLibraryService {
  FontLibraryService._();

  static final FontLibraryService instance = FontLibraryService._();

  /// Bundled catalog of downloadable fonts.
  static const String catalogAsset = 'assets/font_catalog.json';

  static const String _installedKey = 'font_library_installed';
  static const String _selectedKey = 'font_library_pali_font';

  /// Prefix for runtime font families, so a downloaded font can never
  /// collide with a family declared in `pubspec.yaml`.
  static const String _familyPrefix = 'gfont_';

  /// Flutter family name for a catalog font id.
  static String familyFor(String id) => '$_familyPrefix$id';

  final Set<String> _registered = <String>{};
  List<DownloadableFont>? _catalog;

  /// The catalog, read from the bundled asset once per process.
  Future<List<DownloadableFont>> catalog() async {
    final cached = _catalog;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(catalogAsset);
    final list = DownloadableFont.listFromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _catalog = list;
    return list;
  }

  Future<Directory> _fontDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'fonts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(String id) async =>
      File(p.join((await _fontDir()).path, '$id.ttf'));

  /// Ids whose file the app believes it has downloaded.
  Future<Set<String>> installedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_installedKey) ?? const <String>[]).toSet();
  }

  /// Id of the font chosen for Pāli reading, or null for the built-in fonts.
  Future<String?> selectedId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_selectedKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Registers every downloaded font with the engine and applies the saved
  /// choice. Call once, before the first frame: the files are local, so this
  /// is fast, and it makes the reader's first build use the chosen font.
  ///
  /// Files that disappeared (cleared storage, failed copy) are dropped from
  /// the installed list instead of breaking startup.
  Future<FontLibrarySnapshot> restore() async {
    final catalog = await this.catalog();
    final installed = await installedIds();
    final kept = <String>{};
    for (final font in catalog) {
      if (!installed.contains(font.id)) continue;
      try {
        final file = await _fileFor(font.id);
        if (!await file.exists()) continue;
        await _register(font.id, await file.readAsBytes());
        kept.add(font.id);
      } catch (e) {
        debugPrint('[FONTS] could not restore ${font.id}: $e');
      }
    }
    if (kept.length != installed.length) await _saveInstalled(kept);

    final selected = await selectedId();
    DownloadableFont? selectedFont;
    for (final font in catalog) {
      if (font.id == selected) selectedFont = font;
    }
    // A choice whose font is gone falls back to the built-in fonts.
    if (selectedFont != null && !kept.contains(selectedFont.id)) {
      selectedFont = null;
      await _saveSelected(null);
    }
    applySelection(selectedFont);

    return FontLibrarySnapshot(
      catalog: catalog,
      installed: kept,
      selectedId: selectedFont?.id,
    );
  }

  /// Downloads [font], stores it and registers it. [onProgress] receives
  /// 0…1 while the body streams in (not called when the server omits a
  /// length).
  Future<void> download(
    DownloadableFont font, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(font.url);
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', uri));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final total = response.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream) {
        builder.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) throw HttpException('Empty response', uri: uri);

      // Write to a .part file first so an interrupted download never leaves
      // a truncated font that the engine would try to load.
      final file = await _fileFor(font.id);
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);

      await _register(font.id, bytes);
      final installed = await installedIds();
      installed.add(font.id);
      await _saveInstalled(installed);
      onProgress?.call(1);
    } finally {
      client.close();
    }
  }

  /// Deletes a downloaded font. The engine keeps an already-registered
  /// family until the app restarts, but nothing points at it any more.
  Future<void> remove(DownloadableFont font) async {
    try {
      final file = await _fileFor(font.id);
      if (await file.exists()) await file.delete();
      final partial = File('${file.path}.part');
      if (await partial.exists()) await partial.delete();
    } catch (e) {
      debugPrint('[FONTS] could not delete ${font.id}: $e');
    }
    _registered.remove(font.id);
    final installed = await installedIds();
    installed.remove(font.id);
    await _saveInstalled(installed);
    if (await selectedId() == font.id) {
      await _saveSelected(null);
      applySelection(null);
    }
  }

  /// Chooses [font] for Pāli reading (null restores the built-in fonts).
  Future<void> select(DownloadableFont? font) async {
    await _saveSelected(font?.id);
    applySelection(font);
  }

  /// Points Pāli rendering at [font] for every script it covers, or back at
  /// the built-in fonts when null.
  static void applySelection(DownloadableFont? font) {
    if (font == null) {
      setDownloadedPaliFonts(const {});
      return;
    }
    setDownloadedPaliFonts({
      for (final script in font.scripts) script: familyFor(font.id),
    });
  }

  Future<void> _register(String id, Uint8List bytes) async {
    if (!_registered.add(id)) return;
    final loader = FontLoader(familyFor(id));
    loader.addFont(
      Future.value(
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
    await loader.load();
  }

  Future<void> _saveInstalled(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_installedKey, ids.toList()..sort());
  }

  Future<void> _saveSelected(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, id);
    }
  }
}

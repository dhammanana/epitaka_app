import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Access to the Google Fonts catalog and its runtime font loading.
///
/// `google_fonts` fetches a family the first time a style asks for it, caches
/// the file on the device and registers it with the engine under a
/// per-variant name (e.g. `Lora_400regular`). [familyFor] and [apply] return
/// that registered name, so a plain `TextStyle(fontFamily: …)` uses the
/// downloaded file instead of a platform fallback.
///
/// Loading is asynchronous: the first frame after a choice draws with the
/// fallback family and repaints once the file is in — immediate on later
/// launches, since the file is then served from the device cache.
class GoogleFontService {
  GoogleFontService._();

  static final GoogleFontService instance = GoogleFontService._();

  List<String>? _families;
  final Map<String, String> _resolved = <String, String>{};

  /// Every Google Fonts family, alphabetically.
  List<String> get families =>
      _families ??= (List<String>.of(GoogleFonts.asMap().keys)..sort());

  /// Whether the catalog knows [family].
  bool has(String family) => GoogleFonts.asMap().containsKey(family);

  /// Families whose name contains [query], in catalog order. Matching ignores
  /// case and the space between words, so "eb gar" finds "EB Garamond".
  List<String> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return families;
    final squashed = q.replaceAll(' ', '');
    return [
      for (final name in families)
        if (name.toLowerCase().contains(q) ||
            name.toLowerCase().replaceAll(' ', '').contains(squashed))
          name,
    ];
  }

  /// The family name [family] is registered under at the regular weight, or
  /// [family] itself when the catalog does not know it. Calling this also
  /// starts the download.
  String familyFor(String family) {
    final cached = _resolved[family];
    if (cached != null) return cached;
    if (!has(family)) return family;
    final resolved = _styled(family)?.fontFamily ?? family;
    _resolved[family] = resolved;
    return resolved;
  }

  /// [base] restyled in [family], keeping its size, weight and colour. The
  /// variant matching [base]'s weight/style is loaded, so bold and italic
  /// text get the real cut rather than a synthesised one.
  ///
  /// [fallback] is tried for glyphs [family] has no shape for: a Latin Google
  /// font cannot draw Sinhala, so the bundled script font still renders it.
  TextStyle apply(String family, TextStyle base, {String? fallback}) =>
      _styled(family, base: base, fallback: fallback) ?? base;

  /// Starts loading [family] and completes once the file is registered.
  Future<void> warmUp(String family) async {
    if (!has(family)) return;
    try {
      await GoogleFonts.pendingFonts([GoogleFonts.getFont(family)]);
    } catch (_) {
      // Offline or a blocked request: the fallback family stays in use.
    }
  }

  TextStyle? _styled(String family, {TextStyle? base, String? fallback}) {
    if (!has(family)) return null;
    try {
      final styled = GoogleFonts.getFont(
        family,
        textStyle: base,
        fontWeight: base?.fontWeight,
        fontStyle: base?.fontStyle,
      );
      if (fallback == null) return styled;
      return styled.copyWith(
        fontFamilyFallback: [
          fallback,
          if (styled.fontFamily != null) styled.fontFamily!,
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/settings_provider.dart';

/// The reader's default Pāḷi size. The dictionaries start from it, not from
/// the reader's current size, so at 100% they look as they did at the default.
const kDictionaryBasePaliSize = 19.0;

/// 50% to 120%. 100% is the old size. (User, 2026-10-13: 80% was still too
/// big and 150% too high.)
const kDictionaryFontScaleMin = 0.5;
const kDictionaryFontScaleMax = 1.2;

/// The smallest size any dictionary text may be drawn at. The old limits in
/// each surface were set for the reader's size range and stopped the text
/// shrinking below about 80%.
const kDictionaryMinTextSize = 6.0;
const kDictionaryFontScaleStep = 0.05;
const dictionaryFontScalePrefsKey = 'dictionary_font_scale';

/// The scale kept to the slider's range and steps, so a stored value from
/// anywhere lands on a position the slider can show.
double snapDictionaryFontScale(double value) {
  final steps = ((value - kDictionaryFontScaleMin) / kDictionaryFontScaleStep)
      .round();
  final snapped = kDictionaryFontScaleMin + steps * kDictionaryFontScaleStep;
  return snapped
      .clamp(kDictionaryFontScaleMin, kDictionaryFontScaleMax)
      .toDouble();
}

final dictionaryFontScaleProvider =
    StateNotifierProvider<DictionaryFontScaleNotifier, double>(
      (ref) => DictionaryFontScaleNotifier(),
    );

class DictionaryFontScaleNotifier extends StateNotifier<double> {
  DictionaryFontScaleNotifier() : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(dictionaryFontScalePrefsKey);
      if (saved != null && mounted) state = snapDictionaryFontScale(saved);
    } catch (_) {}
  }

  Future<void> setScale(double value) async {
    final next = snapDictionaryFontScale(value);
    if (next == state) return;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(dictionaryFontScalePrefsKey, next);
    } catch (_) {}
  }
}

/// The Pāḷi typography every dictionary surface sizes its text from: the
/// reader's font family, at the dictionary size. Each surface keeps its own
/// ratio and limits on top of it, so titles stay bigger than body text and
/// small print stays smaller.
final dictionaryPaliProvider = Provider<LanguageTypography>((ref) {
  final pali = ref.watch(settingsProvider.select((s) => s.typography.pali));
  final scale = ref.watch(dictionaryFontScaleProvider);
  return pali.copyWith(fontSize: kDictionaryBasePaliSize * scale);
});

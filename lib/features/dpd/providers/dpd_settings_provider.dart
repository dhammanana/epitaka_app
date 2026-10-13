import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much of a DPD headword or root is drawn. The names are the canon's
/// saṅkhittena / vitthārena pair.
enum DictionaryLevel {
  sankhitta('Saṅkhitta', 'Brief'),
  majjhima('Majjhima', 'Standard'),
  vitthara('Vitthāra', 'Full');

  const DictionaryLevel(this.paliName, this.englishName);

  final String paliName;
  final String englishName;
}

/// Display options of the DPD entry. Defaults are the DPD app's own.
class DpdSettings {
  const DpdSettings({
    this.level = DictionaryLevel.majjhima,
    this.grammarOpen = false,
    this.examplesOpen = false,
    this.oneButtonAtATime = true,
  });

  final DictionaryLevel level;
  final bool grammarOpen;
  final bool examplesOpen;
  final bool oneButtonAtATime;

  DpdSettings copyWith({
    DictionaryLevel? level,
    bool? grammarOpen,
    bool? examplesOpen,
    bool? oneButtonAtATime,
  }) => DpdSettings(
    level: level ?? this.level,
    grammarOpen: grammarOpen ?? this.grammarOpen,
    examplesOpen: examplesOpen ?? this.examplesOpen,
    oneButtonAtATime: oneButtonAtATime ?? this.oneButtonAtATime,
  );

  @override
  bool operator ==(Object other) =>
      other is DpdSettings &&
      other.level == level &&
      other.grammarOpen == grammarOpen &&
      other.examplesOpen == examplesOpen &&
      other.oneButtonAtATime == oneButtonAtATime;

  @override
  int get hashCode => Object.hash(level, grammarOpen, examplesOpen, oneButtonAtATime);
}

final dpdSettingsProvider =
    StateNotifierProvider<DpdSettingsNotifier, DpdSettings>(
      (ref) => DpdSettingsNotifier(),
    );

class DpdSettingsNotifier extends StateNotifier<DpdSettings> {
  static const levelKey = 'dpd_level';
  static const grammarOpenKey = 'dpd_grammar_open';
  static const examplesOpenKey = 'dpd_examples_open';
  static const oneButtonAtATimeKey = 'dpd_one_button_at_a_time';

  DpdSettingsNotifier() : super(const DpdSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final saved = prefs.getString(levelKey);
      state = DpdSettings(
        level: DictionaryLevel.values.asNameMap()[saved] ?? state.level,
        grammarOpen: prefs.getBool(grammarOpenKey) ?? state.grammarOpen,
        examplesOpen: prefs.getBool(examplesOpenKey) ?? state.examplesOpen,
        oneButtonAtATime:
            prefs.getBool(oneButtonAtATimeKey) ?? state.oneButtonAtATime,
      );
    } catch (_) {}
  }

  Future<void> _saveString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void setLevel(DictionaryLevel value) {
    if (state.level == value) return;
    state = state.copyWith(level: value);
    _saveString(levelKey, value.name);
  }

  void setGrammarOpen(bool value) {
    if (state.grammarOpen == value) return;
    state = state.copyWith(grammarOpen: value);
    _save(grammarOpenKey, value);
  }

  void setExamplesOpen(bool value) {
    if (state.examplesOpen == value) return;
    state = state.copyWith(examplesOpen: value);
    _save(examplesOpenKey, value);
  }

  void setOneButtonAtATime(bool value) {
    if (state.oneButtonAtATime == value) return;
    state = state.copyWith(oneButtonAtATime: value);
    _save(oneButtonAtATimeKey, value);
  }
}

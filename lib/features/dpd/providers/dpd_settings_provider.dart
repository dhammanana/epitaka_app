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

/// Which recorded voice the pronunciation button plays. The names are what
/// the audio address takes.
enum AudioGender { male, female }

/// Display options of the DPD entry. Defaults are the DPD app's own.
class DpdSettings {
  const DpdSettings({
    this.level = DictionaryLevel.majjhima,
    this.grammarOpen = false,
    this.examplesOpen = false,
    this.oneButtonAtATime = true,
    this.showConstructionInSummary = true,
    this.showSummary = true,
    this.showPartialResults = false,
    this.showFuzzyResults = false,
    this.audioGender = AudioGender.male,
    this.showSandhi = true,
  });

  final DictionaryLevel level;
  final bool grammarOpen;
  final bool examplesOpen;
  final bool oneButtonAtATime;

  /// Saṅkhitta only: the construction after the meaning of a headword line.
  final bool showConstructionInSummary;

  /// The summary list at the top of the page (and, at Saṅkhitta, the whole of
  /// the DPD content, so it shows there whatever this says).
  final bool showSummary;

  /// Headwords that start with the word, under a "Partial Results" heading.
  final bool showPartialResults;

  /// Headwords that sound like the word, under a "Fuzzy Results" heading.
  final bool showFuzzyResults;

  final AudioGender audioGender;

  /// Whether the apostrophe and hyphen that join words inside a Pāḷi word show
  /// in examples and commentary.
  final bool showSandhi;

  DpdSettings copyWith({
    DictionaryLevel? level,
    bool? grammarOpen,
    bool? examplesOpen,
    bool? oneButtonAtATime,
    bool? showConstructionInSummary,
    bool? showSummary,
    bool? showPartialResults,
    bool? showFuzzyResults,
    AudioGender? audioGender,
    bool? showSandhi,
  }) => DpdSettings(
    level: level ?? this.level,
    grammarOpen: grammarOpen ?? this.grammarOpen,
    examplesOpen: examplesOpen ?? this.examplesOpen,
    oneButtonAtATime: oneButtonAtATime ?? this.oneButtonAtATime,
    showConstructionInSummary:
        showConstructionInSummary ?? this.showConstructionInSummary,
    showSummary: showSummary ?? this.showSummary,
    showPartialResults: showPartialResults ?? this.showPartialResults,
    showFuzzyResults: showFuzzyResults ?? this.showFuzzyResults,
    audioGender: audioGender ?? this.audioGender,
    showSandhi: showSandhi ?? this.showSandhi,
  );

  @override
  bool operator ==(Object other) =>
      other is DpdSettings &&
      other.level == level &&
      other.grammarOpen == grammarOpen &&
      other.examplesOpen == examplesOpen &&
      other.oneButtonAtATime == oneButtonAtATime &&
      other.showConstructionInSummary == showConstructionInSummary &&
      other.showSummary == showSummary &&
      other.showPartialResults == showPartialResults &&
      other.showFuzzyResults == showFuzzyResults &&
      other.audioGender == audioGender &&
      other.showSandhi == showSandhi;

  @override
  int get hashCode => Object.hash(
    level,
    grammarOpen,
    examplesOpen,
    oneButtonAtATime,
    showConstructionInSummary,
    showSummary,
    showPartialResults,
    showFuzzyResults,
    audioGender,
    showSandhi,
  );
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
  static const showConstructionInSummaryKey = 'dpd_show_construction_in_summary';
  static const showSummaryKey = 'dpd_show_summary';
  static const showPartialResultsKey = 'dpd_show_partial_results';
  static const showFuzzyResultsKey = 'dpd_show_fuzzy_results';
  static const audioGenderKey = 'dpd_audio_gender';
  static const showSandhiKey = 'dpd_show_sandhi';

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
        showConstructionInSummary:
            prefs.getBool(showConstructionInSummaryKey) ??
            state.showConstructionInSummary,
        showSummary: prefs.getBool(showSummaryKey) ?? state.showSummary,
        showPartialResults:
            prefs.getBool(showPartialResultsKey) ?? state.showPartialResults,
        showFuzzyResults:
            prefs.getBool(showFuzzyResultsKey) ?? state.showFuzzyResults,
        audioGender:
            AudioGender.values.asNameMap()[prefs.getString(audioGenderKey)] ??
            state.audioGender,
        showSandhi: prefs.getBool(showSandhiKey) ?? state.showSandhi,
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

  void setShowConstructionInSummary(bool value) {
    if (state.showConstructionInSummary == value) return;
    state = state.copyWith(showConstructionInSummary: value);
    _save(showConstructionInSummaryKey, value);
  }

  void setShowSummary(bool value) {
    if (state.showSummary == value) return;
    state = state.copyWith(showSummary: value);
    _save(showSummaryKey, value);
  }

  void setShowPartialResults(bool value) {
    if (state.showPartialResults == value) return;
    state = state.copyWith(showPartialResults: value);
    _save(showPartialResultsKey, value);
  }

  void setShowFuzzyResults(bool value) {
    if (state.showFuzzyResults == value) return;
    state = state.copyWith(showFuzzyResults: value);
    _save(showFuzzyResultsKey, value);
  }

  void setAudioGender(AudioGender value) {
    if (state.audioGender == value) return;
    state = state.copyWith(audioGender: value);
    _saveString(audioGenderKey, value.name);
  }

  void setShowSandhi(bool value) {
    if (state.showSandhi == value) return;
    state = state.copyWith(showSandhi: value);
    _save(showSandhiKey, value);
  }
}

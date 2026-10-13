import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Display options of the DPD entry. Defaults are the DPD app's own.
class DpdSettings {
  const DpdSettings({
    this.grammarOpen = false,
    this.examplesOpen = false,
    this.oneButtonAtATime = true,
  });

  final bool grammarOpen;
  final bool examplesOpen;
  final bool oneButtonAtATime;

  DpdSettings copyWith({
    bool? grammarOpen,
    bool? examplesOpen,
    bool? oneButtonAtATime,
  }) => DpdSettings(
    grammarOpen: grammarOpen ?? this.grammarOpen,
    examplesOpen: examplesOpen ?? this.examplesOpen,
    oneButtonAtATime: oneButtonAtATime ?? this.oneButtonAtATime,
  );

  @override
  bool operator ==(Object other) =>
      other is DpdSettings &&
      other.grammarOpen == grammarOpen &&
      other.examplesOpen == examplesOpen &&
      other.oneButtonAtATime == oneButtonAtATime;

  @override
  int get hashCode => Object.hash(grammarOpen, examplesOpen, oneButtonAtATime);
}

final dpdSettingsProvider =
    StateNotifierProvider<DpdSettingsNotifier, DpdSettings>(
      (ref) => DpdSettingsNotifier(),
    );

class DpdSettingsNotifier extends StateNotifier<DpdSettings> {
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
      state = DpdSettings(
        grammarOpen: prefs.getBool(grammarOpenKey) ?? state.grammarOpen,
        examplesOpen: prefs.getBool(examplesOpenKey) ?? state.examplesOpen,
        oneButtonAtATime:
            prefs.getBool(oneButtonAtATimeKey) ?? state.oneButtonAtATime,
      );
    } catch (_) {}
  }

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
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

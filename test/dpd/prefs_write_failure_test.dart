import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/lookup_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A store that reads fine and refuses every write, like a full disk.
class _WriteFailsStore extends InMemorySharedPreferencesStore {
  _WriteFailsStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    throw StateError('disk full');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = _WriteFailsStore();
  });

  test('a failed history save keeps the words in memory and raises nothing',
      () async {
    final history = LookupHistory(persist: true);
    await history.load();
    history
      ..navigateTo('dhamma')
      ..navigateTo('kamma');
    await pumpEventQueue();

    expect(history.words, ['dhamma', 'kamma']);
    history.dispose();
  });

  test('a failed list save keeps the new order in memory and raises nothing',
      () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final store = c.read(dictionaryListStoreProvider.notifier);
    await pumpEventQueue();

    await store.setOrder(['cpd', 'dpd_roots']);

    expect(c.read(dictionaryListStoreProvider)!.order, ['cpd', 'dpd_roots']);
  });
}

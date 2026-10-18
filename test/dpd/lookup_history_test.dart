import 'package:epitaka/features/dpd/providers/lookup_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('an empty list has both buttons off', () {
    final h = LookupHistory();
    expect(h.canGoBack, isFalse);
    expect(h.canGoForward, isFalse);
    expect(h.current, isNull);
    expect(h.goBack(), isNull);
    expect(h.goForward(), isNull);
  });

  test('add, back, forward', () {
    final h = LookupHistory()
      ..navigateTo('dhamma')
      ..navigateTo('kamma')
      ..navigateTo('sati');
    expect(h.current, 'sati');
    expect(h.canGoForward, isFalse);
    expect(h.backWord, 'kamma');

    expect(h.goBack(), 'kamma');
    expect(h.forwardWord, 'sati');
    expect(h.backWord, 'dhamma');
    expect(h.goBack(), 'dhamma');
    expect(h.canGoBack, isFalse);

    expect(h.goForward(), 'kamma');
    expect(h.goForward(), 'sati');
    expect(h.goForward(), isNull);
  });

  test('the same word twice adds once', () {
    final h = LookupHistory()
      ..navigateTo('dhamma')
      ..navigateTo('dhamma');
    expect(h.canGoBack, isFalse);
  });

  test('a word looked up again moves to the end, and is not in the list twice', () {
    final h = LookupHistory()
      ..navigateTo('a')
      ..navigateTo('b')
      ..navigateTo('c')
      ..goBack()
      ..goBack();
    h.navigateTo('a');
    expect(h.words, ['b', 'c', 'a']);
    expect(h.current, 'a');
    expect(h.canGoForward, isFalse);
    expect(h.goBack(), 'c');
  });

  test('the newest word looked up again changes nothing', () {
    final h = LookupHistory()
      ..navigateTo('a')
      ..navigateTo('b')
      ..navigateTo('b');
    expect(h.words, ['a', 'b']);
  });

  test('retyping the last word after a clear adds no copy', () {
    final h = LookupHistory()
      ..navigateTo('a')
      ..navigateTo('b')
      ..resetPosition();
    h.navigateTo('b');
    expect(h.words, ['a', 'b']);
    expect(h.current, 'b');
  });

  test('back then a new word goes to the end and keeps the forward words', () {
    final h = LookupHistory()
      ..navigateTo('a')
      ..navigateTo('b')
      ..navigateTo('c')
      ..goBack()
      ..goBack();
    h.navigateTo('d');
    expect(h.words, ['a', 'b', 'c', 'd']);
    expect(h.current, 'd');
    expect(h.canGoForward, isFalse);
    expect(h.goBack(), 'c');
  });

  test('the list holds 100 words and drops the oldest', () {
    final h = LookupHistory();
    for (var i = 0; i < 105; i++) {
      h.navigateTo('w$i');
    }
    expect(h.words.length, 100);
    expect(h.words.first, 'w5');
    expect(h.words.last, 'w104');
    expect(h.currentIndex, 99);
    expect(h.current, 'w104');
    expect(h.goBack(), 'w103');
  });

  test('resetPosition then back returns to the last word', () {
    final h = LookupHistory()
      ..navigateTo('a')
      ..navigateTo('b')
      ..resetPosition();
    expect(h.current, isNull);
    expect(h.canGoBack, isTrue);
    expect(h.canGoForward, isFalse);
    expect(h.backWord, 'b');
    expect(h.goBack(), 'b');
    expect(h.goBack(), 'a');
  });

  test('a new word after a reset is added at the end', () {
    final h = LookupHistory()
      ..navigateTo('a')
      ..resetPosition()
      ..navigateTo('b');
    expect(h.current, 'b');
    expect(h.goBack(), 'a');
  });

  group('chips and arrows are one list', () {
    test('the words run oldest to newest, and the index is the position', () {
      final h = LookupHistory()
        ..navigateTo('a')
        ..navigateTo('b')
        ..navigateTo('c');
      expect(h.words, ['a', 'b', 'c']);
      expect(h.currentIndex, 2);
      h.goBack();
      expect(h.words, ['a', 'b', 'c']);
      expect(h.currentIndex, 1);
    });

    test('every word is reachable with the back button, with no repeat', () {
      final h = LookupHistory()
        ..navigateTo('a')
        ..navigateTo('b')
        ..navigateTo('a')
        ..navigateTo('c')
        ..goBack()
        ..navigateTo('d');
      final reached = <String>[h.current!];
      for (var w = h.goBack(); w != null; w = h.goBack()) {
        reached.add(w);
      }
      expect(reached.reversed, h.words);
      expect(h.words.toSet().length, h.words.length);
    });
  });

  group('saved', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('a new run reads the words, and back works', () async {
      SharedPreferences.setMockInitialValues({});
      final first = LookupHistory(persist: true);
      await first.load();
      first
        ..navigateTo('dhamma')
        ..navigateTo('kamma');
      await pumpEventQueue();

      final second = LookupHistory(persist: true);
      await second.load();
      expect(second.words, ['dhamma', 'kamma']);
      expect(second.current, isNull, reason: 'position is past the end');
      expect(second.goBack(), 'kamma');
      expect(second.goBack(), 'dhamma');
      first.dispose();
      second.dispose();
    });

    test('a word looked up before the load finishes does not replace the saved list', () async {
      SharedPreferences.setMockInitialValues({
        'dict_lookup_nav': '["dhamma","kamma"]',
      });
      final h = LookupHistory(persist: true);
      final loading = h.load();
      h.navigateTo('sati'); // before the saved words are read
      await loading;
      await pumpEventQueue();

      expect(h.words, ['dhamma', 'kamma', 'sati']);
      expect(h.current, 'sati');
      expect(h.goBack(), 'kamma');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dict_lookup_nav'), '["dhamma","kamma","sati"]');
      h.dispose();
    });

    test('a damaged saved list starts an empty history', () async {
      SharedPreferences.setMockInitialValues({'dict_lookup_nav': 'not json'});
      final h = LookupHistory(persist: true);
      await h.load();
      expect(h.words, isEmpty);
      h.dispose();
    });

    test('a saved list with a word twice keeps its newest place', () async {
      SharedPreferences.setMockInitialValues({
        'dict_lookup_nav': '["ca","dhamma","ca"]',
      });
      final h = LookupHistory(persist: true);
      await h.load();
      expect(h.words, ['dhamma', 'ca']);
      h.dispose();
    });

    test('a saved list of the wrong type starts an empty history', () async {
      SharedPreferences.setMockInitialValues({'dict_lookup_nav': 5});
      final h = LookupHistory(persist: true);
      await h.load();
      expect(h.words, isEmpty);
      h.dispose();
    });

    test('the app provider loads the saved words when first read', () async {
      SharedPreferences.setMockInitialValues({
        'dict_lookup_nav': '["dhamma","kamma"]',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(lookupHistoryProvider, (_, _) {});
      container.read(lookupHistoryProvider);
      await pumpEventQueue();

      final h = container.read(lookupHistoryProvider);
      expect(h.words, ['dhamma', 'kamma']);
      expect(h.backWord, 'kamma');
    });

    test('a user with only the sheet\'s old recent list keeps those words', () async {
      SharedPreferences.setMockInitialValues({
        'dict_search_history': ['sati', 'jhana'],
      });
      final h = LookupHistory(persist: true);
      await h.load();
      expect(h.words, ['jhana', 'sati'], reason: 'oldest first');
      expect(h.goBack(), 'sati');
      h.dispose();
    });

    test('a saved list wins over the old recent list', () async {
      SharedPreferences.setMockInitialValues({
        'dict_search_history': ['sati', 'jhana'],
        'dict_lookup_nav': '["dhamma"]',
      });
      final h = LookupHistory(persist: true);
      await h.load();
      expect(h.words, ['dhamma']);
      h.dispose();
    });
  });
}

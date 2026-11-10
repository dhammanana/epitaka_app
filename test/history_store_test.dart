import 'package:epitaka/features/gavesana/providers/gavesana_history_provider.dart';
import 'package:epitaka/features/search/providers/search_history_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart'
    show AiPassageRef;
import 'package:epitaka/features/sutta_jump/providers/sutta_history_provider.dart';
import 'package:epitaka/features/sutta_jump/services/sutta_code_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

SuttaTarget target(String b, int p, {String title = 'T'}) =>
    SuttaTarget(bookId: b, paraId: p, displayCode: 'MN$p', title: title);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('add puts newest first and a repeat moves to the top', () async {
    final s = SearchHistoryNotifier();
    await settle();
    s.add('a');
    s.add('b');
    s.add('a');
    expect(s.state, ['a', 'b']);
  });

  test('cap of 30 drops the oldest', () async {
    final s = SearchHistoryNotifier();
    await settle();
    for (var i = 0; i < 35; i++) {
      s.add('w$i');
    }
    expect(s.state.length, 30);
    expect(s.state.first, 'w34');
    expect(s.state.last, 'w5');
  });

  test('remove and clear persist', () async {
    final s = SearchHistoryNotifier();
    await settle();
    s.add('a');
    s.add('b');
    s.remove('a');
    await settle();
    expect((await SharedPreferences.getInstance()).getStringList(
      SearchHistoryNotifier.prefsKey,
    ), ['b']);
    s.clear();
    await settle();
    expect((await SharedPreferences.getInstance()).getStringList(
      SearchHistoryNotifier.prefsKey,
    ), isEmpty);
  });

  test('late load keeps an earlier add and puts it first', () async {
    SharedPreferences.setMockInitialValues({
      SearchHistoryNotifier.prefsKey: ['old1', 'old2'],
    });
    final s = SearchHistoryNotifier();
    s.add('new');
    await settle();
    expect(s.state, ['new', 'old1', 'old2']);
  });

  test('clear before the load finishes discards the saved list', () async {
    SharedPreferences.setMockInitialValues({
      SearchHistoryNotifier.prefsKey: ['old1'],
    });
    final s = SearchHistoryNotifier();
    s.clear();
    await settle();
    expect(s.state, isEmpty);
  });

  test('remove before the load finishes is not undone', () async {
    SharedPreferences.setMockInitialValues({
      SearchHistoryNotifier.prefsKey: ['x', 'y'],
    });
    final s = SearchHistoryNotifier();
    s.remove('x');
    await settle();
    expect(s.state, ['y']);
  });

  test('a clear before the load reaches the disk', () async {
    SharedPreferences.setMockInitialValues({
      SearchHistoryNotifier.prefsKey: ['old1'],
    });
    final s = SearchHistoryNotifier();
    s.clear();
    await settle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(SearchHistoryNotifier.prefsKey), isEmpty);
  });

  test('a remove before the load reaches the disk', () async {
    SharedPreferences.setMockInitialValues({
      SearchHistoryNotifier.prefsKey: ['x', 'y'],
    });
    final s = SearchHistoryNotifier();
    s.remove('x');
    await settle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(SearchHistoryNotifier.prefsKey), ['y']);
  });

  test('a notifier disposed before the load does not throw', () async {
    final s = SearchHistoryNotifier();
    s.dispose();
    await settle();
  });

  test('a corrupt saved sutta row is dropped', () async {
    SharedPreferences.setMockInitialValues({
      'goto_sutta_history': ['not json', encodeSutta(target('mn1', 3))],
    });
    final s = SuttaHistoryNotifier();
    await settle();
    expect(s.state.length, 1);
    expect(decodeSutta(s.state.single)!.paraId, 3);
  });

  test('sutta identity ignores a title change', () async {
    final s = SuttaHistoryNotifier();
    await settle();
    s.add(encodeSutta(target('mn1', 3, title: 'old')));
    s.add(encodeSutta(target('mn1', 4)));
    s.add(encodeSutta(target('mn1', 3, title: 'new')));
    expect(s.state.length, 2);
    expect(decodeSutta(s.state.first)!.title, 'new');
  });

  test('gavesana entry round trips and the same question replaces', () async {
    final s = GavesanaHistoryNotifier();
    await settle();
    s.add(encodeGavesana(
      question: 'What is dukkha?',
      terms: ['dukkha'],
      passages: const [AiPassageRef(bookId: 'dn1', paraId: 2)],
    ));
    s.add(encodeGavesana(
      question: ' what is DUKKHA? ',
      terms: ['x'],
      passages: const [AiPassageRef(bookId: 'mn1', paraId: 9)],
    ));
    expect(s.state.length, 1);
    final e = decodeGavesana(s.state.single)!;
    expect(e.terms, ['x']);
    expect(e.passages.single.bookId, 'mn1');
  });

  test('gavesana entry with no passage is rejected', () {
    expect(decodeGavesana('{"q":"a","t":[],"p":[]}'), isNull);
  });
}

import 'package:epitaka/features/deep_links/deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> segs(String link) =>
      DeepLinkService.routeSegments(Uri.parse(link));

  test('custom-scheme search link routes to search', () {
    expect(segs('epitaka://search?q=dhamma%20vinaya'), ['search']);
  });

  test('custom-scheme reader link keeps the book id after reader', () {
    expect(segs('epitaka://reader/dn1?paraId=3'), ['reader', 'dn1']);
  });

  test('universal search link strips the /app prefix', () {
    expect(segs('https://epitaka.org/app/search?q=x'), ['search']);
  });

  test('search query is cleaned before it opens search', () {
    expect(
      DeepLinkService.searchQueryOf(Uri.parse('epitaka://search?q=dhamma%27')),
      'dhamma',
    );
    expect(
      DeepLinkService.searchQueryOf(
        Uri.parse('epitaka://search?q=dhamma-vinaya%E1%B9%83'),
      ),
      'dhammavinayaṃ',
    );
  });

  group('dropRepeatedInitialLink', () {
    final a = Uri.parse('epitaka://search?q=a');
    final b = Uri.parse('epitaka://search?q=b');
    Future<List<Uri>> run(List<Uri> events, Uri? initial) =>
        DeepLinkService.dropRepeatedInitialLink(
          Stream.fromIterable(events),
          initial,
        ).toList();

    test('drops the stream repeat of the launch link', () async {
      expect(await run([a, a, b], a), [a, b]);
    });
    test('keeps everything when there was no launch link', () async {
      expect(await run([a, a, b], null), [a, a, b]);
    });
    test('only the first event can be the repeat', () async {
      expect(await run([b, a], a), [b, a]);
    });
  });

  test('canonical universal reader link keeps lang, book and slug', () {
    expect(
      segs('https://epitaka.org/app/en/dn1/the-net-of-views-123#123-45'),
      ['en', 'dn1', 'the-net-of-views-123'],
    );
  });
}

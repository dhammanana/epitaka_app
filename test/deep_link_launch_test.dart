/// A link that launches the app on desktop arrives as a command-line argument
/// and, where the plugin sees it, through app_links as well. It must open once.
library;

import 'package:epitaka/features/deep_links/deep_link_service.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/sutta_link_harness.dart';

void main() {
  tearDown(() {
    DeepLinkService.launchArgLink = null;
    DeepLinkService.initialLinkOverride = null;
  });

  final link = Uri.parse('epitaka://sutta?code=an4.126');

  test('the launch link is the first epitaka argument', () {
    expect(
      DeepLinkService.launchLinkOf([
        '--flag',
        'epitaka://sutta?code=an4.126',
        'epitaka://search?q=x',
      ]),
      'epitaka://sutta?code=an4.126',
    );
    expect(DeepLinkService.launchLinkOf(['--flag', 'file.txt']), isNull);
    expect(DeepLinkService.launchLinkOf(const []), isNull);
  });

  testWidgets('a link only in the arguments opens the sutta and counts as a '
      'launch link', (tester) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    DeepLinkService.launchArgLink = link;
    DeepLinkService.initialLinkOverride = () async => null;
    final container = await pumpSuttaLinkApp(tester, db);
    await settleLink(tester);

    final tab = container.read(readerTabsProvider).activeTab!;
    expect((tab.bookId, tab.initialParaId), ('A-iv', 1114));
    expect(tab.initialJumpId, 1);
    expect(await DeepLinkService.instance.hasLaunchLink(), isTrue);
  });

  testWidgets('the same link from app_links and the arguments opens once', (
    tester,
  ) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    DeepLinkService.launchArgLink = link;
    DeepLinkService.initialLinkOverride = () async => link;
    // A second open of the same book would change the tab state again.
    var changes = 0;
    final container = await pumpSuttaLinkApp(
      tester,
      db,
      beforeLinks: (c) => c.listen(readerTabsProvider, (_, _) => changes++),
    );
    await settleLink(tester);

    expect(container.read(readerTabsProvider).tabs, hasLength(1));
    expect(changes, 1);
  });

  testWidgets('no launch link means nothing opens', (tester) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    DeepLinkService.initialLinkOverride = () async => null;
    final container = await pumpSuttaLinkApp(tester, db);
    await settleLink(tester);

    expect(container.read(readerTabsProvider).tabs, isEmpty);
    expect(await DeepLinkService.instance.hasLaunchLink(), isFalse);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:epitaka/features/desktop/single_instance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a second launch is refused, nudges the first, and a dead first copy '
      'leaves no stale lock', () async {
    final dir = await Directory.systemTemp.createTemp('single_instance');
    addTearDown(() => dir.delete(recursive: true));

    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final dart = flutterRoot == null ? 'dart' : '$flutterRoot/bin/dart';
    final holder = await Process.start(
      dart,
      ['test/support/hold_single_instance.dart', dir.path],
    );
    addTearDown(() => holder.kill(ProcessSignal.sigkill));

    final lines = holder.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
    final seen = <String>[];
    lines.listen(seen.add, onError: (_) {});
    final nudged = lines.firstWhere((l) => l == 'nudged');
    // Killing the holder closes the stream; without a handler that error
    // would surface as unhandled when the test has already failed elsewhere.
    nudged.catchError((_) => '');
    final claimLine = await lines
        .firstWhere((l) => l.startsWith('claimed:'))
        .timeout(const Duration(seconds: 30));
    expect(claimLine, 'claimed:true');

    // A bare launch: the window comes forward, no link reaches the handler.
    final second = await claimSingleInstance(
      dir,
      onAnotherLaunch: () {},
      onLink: (_) {},
    );
    expect(second, isFalse);
    await nudged.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(seen.where((l) => l.startsWith('link:')), isEmpty);

    // A line over 2 KB, and a line with no newline, are refused.
    final port = int.parse(
      (await File('${dir.path}/single_instance.port').readAsString()).trim(),
    );
    Future<void> raw(String text) async {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      socket.write(text);
      await socket.flush();
      await socket.close();
      socket.destroy();
    }

    await raw('epitaka://sutta?code=${'a' * 3000}\n');
    await raw('epitaka://sutta?code=an4.126');
    await raw('epitaka://login-callback/?code=x\n');
    await raw('epitaka://sutta/login-callback?code=x\n');
    await raw('epitaka://other?code=x\n');
    await raw('not a link\n');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(seen.where((l) => l.startsWith('link:')), isEmpty);

    // A second launch with a link: the link reaches the first copy.
    final withLink = await claimSingleInstance(
      dir,
      launchLink: 'epitaka://sutta?code=an4.126',
      onAnotherLaunch: () {},
      onLink: (_) {},
    );
    expect(withLink, isFalse);
    await lines
        .firstWhere((l) => l.startsWith('link:'))
        .timeout(const Duration(seconds: 5));
    expect(
      seen.where((l) => l.startsWith('link:')).single,
      'link:epitaka://sutta?code=an4.126',
    );

    // The port file may still hold the port of an earlier run. The second
    // launch keeps trying until the real port is written, and its link arrives.
    final portFile = File('${dir.path}/single_instance.port');
    final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close();
    await portFile.writeAsString('$deadPort');
    final restored = Future<void>.delayed(
      const Duration(milliseconds: 600),
      () => portFile.writeAsString('$port'),
    );
    final afterStale = await claimSingleInstance(
      dir,
      launchLink: 'epitaka://sutta?code=mn10',
      onAnotherLaunch: () {},
      onLink: (_) {},
    );
    await restored;
    expect(afterStale, isFalse);
    await lines
        .firstWhere((l) => l == 'link:epitaka://sutta?code=mn10')
        .timeout(const Duration(seconds: 5));

    holder.kill(ProcessSignal.sigkill);
    await holder.exitCode;
    expect(
      await claimSingleInstance(
        dir,
        onAnotherLaunch: () {},
        onLink: (_) {},
      ),
      isTrue,
    );
    // A cold `dart` start for the helper can take longer than the default.
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('acceptedSocketLink', () {
    test('sutta, reader and search links pass', () {
      expect(
        acceptedSocketLink('epitaka://sutta?code=an4.126\n'),
        Uri.parse('epitaka://sutta?code=an4.126'),
      );
      expect(
        acceptedSocketLink('epitaka://search?q=dhamma'),
        Uri.parse('epitaka://search?q=dhamma'),
      );
      expect(
        acceptedSocketLink('epitaka://reader/dn1?paraId=3&lineId=2'),
        Uri.parse('epitaka://reader/dn1?paraId=3&lineId=2'),
      );
    });

    test('a reader link keeps a numeric position, and nothing else after #', () {
      expect(
        acceptedSocketLink('epitaka://reader/mn1#123-45'),
        Uri.parse('epitaka://reader/mn1#123-45'),
      );
      expect(
        acceptedSocketLink('epitaka://reader/mn1#123'),
        Uri.parse('epitaka://reader/mn1#123'),
      );
      expect(
        acceptedSocketLink('epitaka://reader/mn1#top'),
        Uri.parse('epitaka://reader/mn1'),
      );
    });

    test('a reader link keeps only its book id, and a sutta link no path', () {
      expect(
        acceptedSocketLink('epitaka://reader/dn1/extra?paraId=3'),
        Uri.parse('epitaka://reader/dn1?paraId=3'),
      );
      expect(
        acceptedSocketLink('epitaka://sutta/extra?code=x#frag'),
        Uri.parse('epitaka://sutta?code=x'),
      );
    });

    test('the sign-in link, other hosts and other schemes are refused', () {
      expect(acceptedSocketLink('epitaka://login-callback/?code=x'), isNull);
      expect(acceptedSocketLink('epitaka://sutta/login-callback?code=x'),
          isNull);
      expect(acceptedSocketLink('epitaka://reader/login-callback'), isNull);
      expect(acceptedSocketLink('epitaka://other?code=x'), isNull);
      expect(acceptedSocketLink('https://epitaka.org/app/sutta?code=x'), isNull);
      expect(acceptedSocketLink('not a link'), isNull);
      expect(acceptedSocketLink(''), isNull);
    });
  });
}

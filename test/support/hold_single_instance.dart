// Run as a separate process by single_instance_test.dart: the lock only
// excludes another process, never a second claim from the same one.
import 'dart:async';
import 'dart:io';

import 'package:epitaka/features/desktop/single_instance.dart';

Future<void> main(List<String> args) async {
  final claimed = await claimSingleInstance(
    Directory(args.single),
    onAnotherLaunch: () => stdout.writeln('nudged'),
  );
  stdout.writeln('claimed:$claimed');
  await Completer<void>().future;
}

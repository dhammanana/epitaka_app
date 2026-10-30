// Generates lib/core/utils/app_version.g.dart from pubspec.yaml, so the app
// reports the version it was built from on every platform and in every build
// mode — no bundle metadata (Info.plist, version.json, exe resource) needed.
//
//   dart run tool/gen_app_version.dart          # write the file
//   dart run tool/gen_app_version.dart --check  # fail if it is stale (CI)
//
// Release builds may still re-stamp the number for a tag that outranks
// pubspec: see --dart-define=APP_VERSION in the build workflow.
import 'dart:io';

const _pubspecPath = 'pubspec.yaml';
const _outputPath = 'lib/core/utils/app_version.g.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final pubspec = File(_pubspecPath);
  if (!pubspec.existsSync()) {
    stderr.writeln(
      'gen_app_version: $_pubspecPath not found — run from the project root',
    );
    exit(1);
  }

  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  if (match == null) {
    stderr.writeln('gen_app_version: no "version:" line in $_pubspecPath');
    exit(1);
  }

  final raw = match.group(1)!;
  final plus = raw.indexOf('+');
  final version = plus < 0 ? raw : raw.substring(0, plus);
  final buildNumber = plus < 0 ? '0' : raw.substring(plus + 1);

  final contents =
      '''
// GENERATED FILE — do not edit by hand.
// Source: pubspec.yaml `version: $raw`
// Regenerate with: dart run tool/gen_app_version.dart

/// The version in `pubspec.yaml` (the part before `+`).
const String kPubspecAppVersion = '$version';

/// The build number in `pubspec.yaml` (the part after `+`, `0` when absent).
const String kPubspecAppBuildNumber = '$buildNumber';
''';

  final output = File(_outputPath);
  if (check) {
    if (!output.existsSync() || output.readAsStringSync() != contents) {
      stderr.writeln(
        'gen_app_version: $_outputPath is stale — run '
        '`dart run tool/gen_app_version.dart`',
      );
      exit(1);
    }
    stdout.writeln(
      'gen_app_version: $_outputPath is up to date ($version+$buildNumber)',
    );
    return;
  }

  output.writeAsStringSync(contents);
  stdout.writeln('gen_app_version: wrote $_outputPath ($version+$buildNumber)');
}

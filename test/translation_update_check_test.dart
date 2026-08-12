// Regression test for the translation update check.
//
// The bug: translations bundled with the app (e.g. English, copied from
// assets on first launch) never go through the download flow, so they have
// no recorded `version_updated_<key>` date in prefs. The old
// `isUpdateAvailable` returned false when no date was recorded, so bundled
// translations NEVER showed an "Update" button even when a newer database
// was published. The fix falls back to the installed DB file's last-modified
// date, so a newer manifest date still surfaces as an update.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/models/translation_version.dart';
import '../lib/features/settings/providers/translation_download_provider.dart';

TranslationVersion _version({
  required String lang,
  String? suffix,
  String? updatedAt,
  bool isAvailable = true,
}) {
  final filename = suffix != null && suffix.isNotEmpty
      ? 'epitaka_${lang}_$suffix.db'
      : 'epitaka_$lang.db';
  return TranslationVersion(
    languageCode: lang,
    suffix: suffix,
    filename: filename,
    isAvailable: isAvailable,
    downloadUrl: 'https://example.com/$filename.zip',
    updatedAt: updatedAt,
  );
}

/// Format a [DateTime] as `yyyy-MM-dd` (the manifest date format).
String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Dates relative to "now" so the tests never rot when run in a
  // different year than the one they were written in.
  final now = DateTime.now();
  final today = _date(now);
  final weekAgo = now.subtract(const Duration(days: 7));

  group('TranslationDownloadNotifier.isUpdateAvailable', () {
    test(
      'bundled translation (no recorded date) shows update when manifest '
      'date is newer than the installed file',
      () async {
        SharedPreferences.setMockInitialValues({});
        final dir = Directory.systemTemp.createTempSync('epitaka_upd');
        try {
          // Simulate a bundled DB copied to disk a week ago.
          final file = File(p.join(dir.path, 'epitaka_en.db'));
          file.createSync();
          file.setLastModifiedSync(weekAgo);

          final en = _version(lang: 'en', updatedAt: today);

          final hasUpdate = await TranslationDownloadNotifier.isUpdateAvailable(
            en,
            dbDir: dir,
          );
          expect(hasUpdate, isTrue,
              reason: 'bundled en with older file must show an update');
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );

    test('downloaded translation (recorded date) shows update when dates differ',
        () async {
      // Simulate the pref recorded when the user last downloaded: old date.
      SharedPreferences.setMockInitialValues({
        'version_updated_en': _date(weekAgo),
      });
      final dir = Directory.systemTemp.createTempSync('epitaka_upd');
      try {
        final en = _version(lang: 'en', updatedAt: today);
        final hasUpdate = await TranslationDownloadNotifier.isUpdateAvailable(
          en,
          dbDir: dir,
        );
        expect(hasUpdate, isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('no update when recorded date matches the manifest date', () async {
      SharedPreferences.setMockInitialValues({
        'version_updated_en': today,
      });
      final dir = Directory.systemTemp.createTempSync('epitaka_upd');
      try {
        final en = _version(lang: 'en', updatedAt: today);
        final hasUpdate = await TranslationDownloadNotifier.isUpdateAvailable(
          en,
          dbDir: dir,
        );
        expect(hasUpdate, isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('no update when manifest has no date', () async {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory.systemTemp.createTempSync('epitaka_upd');
      try {
        final en = _version(lang: 'en');
        final hasUpdate = await TranslationDownloadNotifier.isUpdateAvailable(
          en,
          dbDir: dir,
        );
        expect(hasUpdate, isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('no update when version is not installed locally', () async {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory.systemTemp.createTempSync('epitaka_upd');
      try {
        final en = _version(lang: 'en', updatedAt: today);
        final hasUpdate = await TranslationDownloadNotifier.isUpdateAvailable(
          en.copyWith(isAvailable: false),
          dbDir: dir,
        );
        expect(hasUpdate, isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('recorded date wins over file date for downloaded translations',
        () async {
      // Even if the file is old on disk, a matching recorded pref means no
      // update (the pref reflects the version the user actually downloaded).
      SharedPreferences.setMockInitialValues({
        'version_updated_en': today,
      });
      final dir = Directory.systemTemp.createTempSync('epitaka_upd');
      try {
        final file = File(p.join(dir.path, 'epitaka_en.db'));
        file.createSync();
        file.setLastModifiedSync(weekAgo);

        final en = _version(lang: 'en', updatedAt: today);
        final hasUpdate = await TranslationDownloadNotifier.isUpdateAvailable(
          en,
          dbDir: dir,
        );
        expect(hasUpdate, isFalse,
            reason: 'pref date matches manifest → up to date');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}

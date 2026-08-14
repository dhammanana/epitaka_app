/// Shared drift executor factory.
///
/// The app's SQLite databases are queried from many features (reader, full
/// text search, dictionary, AI tools). A plain `NativeDatabase(file)` runs
/// every query on the main isolate, so slow queries — full-canon LIKE scans,
/// FTS/BM25 matches, index builds — freeze the UI thread and Android shows
/// the "App isn't responding" dialog (the Vimaṃsa / Gavesana AI tool searches
/// used to trigger this).
///
/// On mobile and desktop this opens the database in a **background isolate**
/// ([NativeDatabase.createInBackground]) so queries never block the UI.
/// Drift cannot run in a background isolate on web (no isolate + FFI there),
/// so web keeps the inline executor — web is single-threaded regardless.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Open a drift [NativeDatabase] on [file] without blocking the UI thread.
///
/// [setup] runs after the database is opened, inside the background isolate
/// when one is used (see drift docs for the caveats).
QueryExecutor openDriftExecutor(
  File file, {
  DatabaseSetup? setup,
  bool logStatements = false,
}) {
  if (kIsWeb) {
    return NativeDatabase(
      file,
      setup: setup,
      logStatements: logStatements,
    );
  }
  return NativeDatabase.createInBackground(
    file,
    setup: setup,
    logStatements: logStatements,
  );
}

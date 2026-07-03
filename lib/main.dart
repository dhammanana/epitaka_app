import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/utils/database_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Copy bundled databases from assets to writable storage (needed on
  // Android/iOS where assets aren't directly file-system accessible).
  await ensureBundledDatabases();

  runApp(const ProviderScope(child: EpitakaApp()));
}

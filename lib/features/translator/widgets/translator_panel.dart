// lib/features/translator/widgets/translator_panel.dart
//
// Desktop sidebar panel for the Translation Builder. Embeds the full
// settings body (embedded mode) so the feature is usable right from the
// sidebar — the same screen the drawer/full-screen route opens.

import 'package:flutter/material.dart';

import '../screens/translator_settings_screen.dart';

/// The Translation Builder panel shown in the desktop sidebar.
class TranslatorPanel extends StatelessWidget {
  const TranslatorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const TranslatorSettingsScreen(embedded: true);
  }
}

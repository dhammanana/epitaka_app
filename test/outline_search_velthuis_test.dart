import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/outline/models/outline_models.dart';
import 'package:epitaka/features/outline/providers/outline_provider.dart';
import 'package:epitaka/features/outline/screens/outline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/type_keys.dart';

void main() {
  testWidgets(
      'outline search: Velthuis turns into diacritics; the more menu shows',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outlineProvider('dn1').overrideWith(
            (ref) async => const [
              OutlineGroup(
                title: 'Sīlakkhandhavagga',
                suttas: [
                  OutlineSutta(
                    title: 'Brahmajāla',
                    items: [
                      OutlineItem(
                        paraId: 1,
                        sectionEnd: 10,
                        title: 'Paribbājakakathā',
                        level: 1,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          settingsProvider.overrideWith((ref) {
            final notifier = SettingsNotifier(null);
            notifier.state = const AppSettings();
            return notifier;
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: [AppLocalizationsDelegate()],
          home: OutlineScreen(bookId: 'dn1'),
        ),
      ),
    );
    // The box shows at once (spec I).
    await tester.pumpAndSettle();
    final help = find.descendant(
      of: find.byType(TextField),
      matching: find.byIcon(Icons.more_vert),
    );
    expect(help, findsOneWidget);

    await typeKeys(tester, find.byType(TextField), 'paali');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'pāli',
    );
  });
}

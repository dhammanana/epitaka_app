import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/gavesana/widgets/gavesana_search_view.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/type_keys.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Velthuis turns into diacritics; the help icon shows, empty or with text',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [AppLocalizationsDelegate()],
          home: Scaffold(body: GavesanaSearchView()),
        ),
      ),
    );
    await tester.pump();
    final help = find.descendant(
      of: find.byType(TextField),
      matching: find.byType(VelthuisHelpIcon),
    );
    expect(help, findsOneWidget);

    expect(tester.widget<VelthuisHelpIcon>(help).sanskrit, isFalse);

    await typeKeys(tester, find.byType(TextField), 'paali "sati"');
    await tester.pump();
    expect(help, findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);
    // English is typed here: no Sanskrit rules, so the quote stays.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'pāli "sati"',
    );
  });
}

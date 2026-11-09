import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/gavesana/widgets/gavesana_search_view.dart';
import 'package:epitaka/shared/widgets/search_box_actions.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/type_keys.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Velthuis turns into diacritics; the box ends in the help icon, empty or with text',
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
    final suffix = find.descendant(
      of: find.byType(TextField),
      matching: find.byType(SearchBoxSuffixActions),
    );
    expect(suffix, findsOneWidget);
    // The menu would hold only the help, so the icon stands in for it.
    final help = find.descendant(
      of: find.byType(TextField),
      matching: find.byIcon(Icons.help_outline),
    );
    expect(help, findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    // English is typed here: the help card leaves out the Sanskrit rows,
    // so the box carries that flag for the card it shows.
    expect(tester.widget<SearchBoxSuffixActions>(suffix).sanskrit, isFalse);
    expect(
      tester.widget<VelthuisHelpIcon>(find.byType(VelthuisHelpIcon)).sanskrit,
      isFalse,
    );

    await typeKeys(tester, find.byType(TextField), 'paali "sati"');
    await tester.pump();
    expect(help, findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'pāli "sati"',
    );
  });
}

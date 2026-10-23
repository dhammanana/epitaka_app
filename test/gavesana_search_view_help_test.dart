import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/gavesana/widgets/gavesana_search_view.dart';
import 'package:epitaka/shared/widgets/search_box_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/type_keys.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Velthuis turns into diacritics; the box ends in the more menu, empty or with text',
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

    // English is typed here: the help card leaves out the Sanskrit rows,
    // so the menu carries that flag for the dialog it opens.
    expect(tester.widget<SearchBoxSuffixActions>(suffix).sanskrit, isFalse);

    await typeKeys(tester, find.byType(TextField), 'paali "sati"');
    await tester.pump();
    expect(suffix, findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'pāli "sati"',
    );
  });
}

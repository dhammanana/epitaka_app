import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/script_converter/screens/script_converter_screen.dart';
import 'package:epitaka/features/script_converter/widgets/script_converter_panel.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers/type_keys.dart';

Widget _scope(Widget app) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) {
      final notifier = SettingsNotifier(null);
      notifier.state = const AppSettings();
      return notifier;
    }),
  ],
  child: app,
);

Future<void> _typeAndCheck(WidgetTester tester) async {
  await tester.pump();
  final field = find.byType(TextField).first;
  expect(
    find.descendant(of: field, matching: find.byType(VelthuisHelpIcon)),
    findsOneWidget,
  );
  await typeKeys(tester, field, 'dhamma.m');
  await tester.pump();
  expect(tester.widget<TextField>(field).controller!.text, 'dhammaṃ');

  // A pasted canon passage keeps its own spelling.
  await tester.enterText(field, 'theraapadaana');
  await tester.pump();
  expect(tester.widget<TextField>(field).controller!.text, 'theraapadaana');
}

void main() {
  testWidgets('desktop panel: Velthuis converts; the help icon shows',
      (tester) async {
    await tester.pumpWidget(
      _scope(
        const MaterialApp(
          localizationsDelegates: [AppLocalizationsDelegate()],
          home: Scaffold(body: ScriptConverterPanel()),
        ),
      ),
    );
    await _typeAndCheck(tester);
  });

  testWidgets('phone screen: Velthuis converts; the help icon shows',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ScriptConverterScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      _scope(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [AppLocalizationsDelegate()],
        ),
      ),
    );
    await _typeAndCheck(tester);
  });
}

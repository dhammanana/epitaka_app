import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/desktop/desktop_activity_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the Gavesana button says "Gavesanā AI Search"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: DesktopActivityBar(
              activeSidebar: null,
              vimamsaActive: false,
              onToggleSidebar: (_) {},
              onToggleVimamsa: () {},
              onResetLayout: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Gavesanā AI Search'), findsOneWidget);
    expect(find.byTooltip('Gavesanā'), findsNothing);
  });
}

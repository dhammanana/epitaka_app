/// The DPD widgets that had fixed sizes (buttons, play icons, footers, the
/// frequency table) follow the dictionary text size.
library;

import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart' show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/models/frequency_data.dart';
import 'package:epitaka/features/dpd/utils/text_size.dart';
import 'package:epitaka/features/dpd/widgets/entry_content.dart';
import 'package:epitaka/features/dpd/widgets/frequency_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';

final _theme = AppTheme.forPreference(
  ThemePreference.light,
  platformBrightness: Brightness.light,
);

/// A page whose body text is [body] px, as `DpdResultsView` sets it.
Widget page(double body, Widget child) => ProviderScope(
  child: MaterialApp(
    theme: _theme.copyWith(
      textTheme: _theme.textTheme.copyWith(
        bodyMedium: _theme.textTheme.bodyMedium?.copyWith(fontSize: body),
      ),
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  late FrequencyData data;
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('dpd_text_size_test');
    final file = buildDpdFixture(dir);
    final db = sqlite3.open(file.path);
    final json = db
        .select('SELECT freq_data FROM dpd_headwords WHERE id = 34626')
        .first
        .values
        .first as String;
    db.dispose();
    data = parseFrequencyData(json)!;
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  void wide(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  test('the helper keeps a size in proportion to the body text', () {
    expect(kDpdDefaultBodySize, 15.2);
  });

  testWidgets('a section button grows with the body text', (tester) async {
    wide(tester);
    Future<double> measure(double body) async {
      await tester.pumpWidget(
        page(
          body,
          DpdSectionButton(label: 'grammar', isActive: false, onTap: () {}),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      return tester.getSize(find.text('grammar')).height;
    }

    final normal = await measure(15.2);
    final big = await measure(22.8);
    expect(big / normal, closeTo(1.5, 0.1));
  });

  testWidgets('a play button and its icon grow with the body text', (
    tester,
  ) async {
    wide(tester);
    Future<(double, double)> measure(double body) async {
      await tester.pumpWidget(
        page(body, const DpdPlayButton(lemma: 'dhamma', gender: 'male')),
      );
      await tester.pump(const Duration(seconds: 1));
      return (
        tester.getSize(find.byType(DpdPlayButton)).height,
        tester.getSize(find.byIcon(Icons.play_arrow)).height,
      );
    }

    final (boxN, iconN) = await measure(15.2);
    final (boxB, iconB) = await measure(22.8);
    expect(iconB / iconN, closeTo(1.5, 0.05));
    expect(boxB, greaterThan(boxN * 1.3));
  });

  group('the frequency table', () {
    Future<Size> sizeAt(WidgetTester tester, double scale) async {
      wide(tester);
      await tester.pumpWidget(
        page(15.2, FrequencyTable(data: data, scale: scale)),
      );
      return tester.getSize(find.byType(FrequencyTable));
    }

    testWidgets('is roomier than before, and scales with the text size', (
      tester,
    ) async {
      final one = await sizeAt(tester, 1.0);
      final big = await sizeAt(tester, 1.2);
      expect(one.width, closeTo(652, 1));
      expect(one.height, closeTo(38 * 30, 1));
      expect(big.width / one.width, closeTo(1.2, 0.02));
      expect(big.height / one.height, closeTo(1.2, 0.02));
    });

    testWidgets('puts the room inside the cells, not between them', (
      tester,
    ) async {
      await sizeAt(tester, 1.0);
      // A heat-map cell is a Container holding one number, on a 56 px grid
      // with a half-pixel margin: 1 px between neighbours.
      final cells = <Rect>[
        for (final e in find.byType(Container).evaluate())
          if ((e.widget as Container).child is Text &&
              (e.widget as Container).decoration is BoxDecoration &&
              (e.widget as Container).margin == const EdgeInsets.all(0.5) &&
              (tester.getSize(find.byWidget(e.widget)).width - 56).abs() < 0.5)
            tester.getRect(find.byWidget(e.widget)),
      ];
      expect(cells.length, greaterThan(20));
      final first = cells.first;
      final sameRow = [
        for (final c in cells)
          if ((c.top - first.top).abs() < 0.5) c.left,
      ]..sort();
      expect(sameRow.length, greaterThan(1));
      final step = sameRow[1] - sameRow[0];
      expect(step, closeTo(56, 0.5));
      // The drawn box is the grid square less the margin on both sides.
      final inner = first.deflate(0.5);
      expect(step - inner.width, closeTo(1, 0.1));
      expect(inner.width, greaterThanOrEqualTo(55));
      expect(inner.height, greaterThanOrEqualTo(37));
    });
  });
}

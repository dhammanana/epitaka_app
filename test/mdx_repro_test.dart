import 'dart:convert';
import 'dart:io';

import 'package:dict_reader/dict_reader.dart';
import 'package:epitaka/features/mdx_dictionary/services/mdx_index_service.dart';
import 'package:epitaka/features/mdx_dictionary/services/mdx_text.dart';
import 'package:epitaka/features/mdx_dictionary/widgets/mdx_definition_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hidden content renders after sanitize', (tester) async {
    const raw =
        '<style>.hid{display:none}</style><p class="hid">secret</p><p>shown</p>';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Html(data: raw)),
      ),
    );
    expect(find.text('shown', findRichText: true), findsWidgets);
    expect(find.text('secret', findRichText: true), findsNothing);

    final clean = mdxSanitizeCss('.hid{display:none}');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Html(data: '<style>$clean</style><p class="hid">secret</p>'),
        ),
      ),
    );
    expect(find.text('secret', findRichText: true), findsWidgets);
  });

  const mdxPath = '/Volumes/Data/Dictionaries/LDOCE6/LDOCE6.mdx';
  // The dictionary lives on one developer's Mac. Elsewhere the file read
  // never completes inside testWidgets and the whole suite hangs until the
  // 10-minute timeout.
  testWidgets('real LDOCE6 entry renders without crash',
      skip: !File(mdxPath).existsSync(), (tester) async {
    final svc = MdxIndexService();
    late final String entry;
    final mdx = DictReader(mdxPath);
    try {
      await mdx.initDict();
      final info = await mdx.locate('hello');
      entry = await mdx.readOneMdx(info!);
    } finally {
      await mdx.close();
    }
    final hrefs = mdxStylesheetHrefs(entry);
    final blocks = <String>[];
    for (final h in hrefs) {
      final bytes = await svc.readResourceBytes(mdxPath: mdxPath, key: h);
      if (bytes != null) {
        blocks.add(mdxSanitizeCss(utf8.decode(bytes, allowMalformed: true)));
      }
    }
    await svc.dispose();
    final html =
        '${blocks.map((b) => '<style>$b</style>').join()}${mdxStripStylesheetLinks(entry)}';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Html(
                data: mdxSanitize(html),
                extensions: [MdxImageExtension('test')],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('hello', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

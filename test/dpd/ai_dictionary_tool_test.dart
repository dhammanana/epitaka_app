import 'dart:convert';
import 'dart:io';

import 'package:epitaka/core/providers/pali_definition_provider.dart';
import 'package:epitaka/features/ai_qa/services/ai_qa_tool_service.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_ai_tool_test');
    final file = buildDpdFixture(dir);
    container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith((ref) async => file),
        // The canon-occurrence half of the tool reads the real app database.
        paliDefinitionProvider.overrideWith((ref, word) async => []),
      ],
    );
  });

  tearDownAll(() async {
    container.dispose();
    await dir.delete(recursive: true);
  });

  Future<List<dynamic>> lookups(String term) async {
    final result = await container
        .read(aiQaToolServiceProvider)
        .getDictionary({'term': term});
    expect(result.success, isTrue);
    return (jsonDecode(result.data) as Map<String, dynamic>)['lookups']
        as List<dynamic>;
  }

  test('an exact word returns its headwords with a plain meaning', () async {
    final found = await lookups('dhamma');
    expect(found, hasLength(1));
    final entry = found.single as Map<String, dynamic>;
    expect(entry['lookup_key'], 'dhamma');
    final headwords = (entry['headwords'] as List).cast<Map<String, dynamic>>();
    expect(headwords.first['lemma'], 'dhamma');
    expect(headwords.first['meaning'], startsWith('nature; character'));
  });

  test('no exact word falls back to keys that start with the term', () async {
    final found = await lookups('satip');
    final keys = found.map((e) => (e as Map)['lookup_key']).toList();
    expect(keys, ['satipaṭṭhāna']);
  });

  test('a found word carries no error note', () async {
    final result = await container
        .read(aiQaToolServiceProvider)
        .getDictionary({'term': 'dhamma'});
    expect(jsonDecode(result.data), isNot(contains('dpd_error')));
  });

  // Empty lookups with no reason read as "the word is unknown". The model has
  // to be told that the dictionary is missing.
  test('a missing DPD file says so instead of an empty answer', () async {
    final missing = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith(
          (ref) async => File('${dir.path}/not-there.db'),
        ),
        paliDefinitionProvider.overrideWith((ref, word) async => []),
      ],
    );
    addTearDown(missing.dispose);

    final result = await missing
        .read(aiQaToolServiceProvider)
        .getDictionary({'term': 'dhamma'});
    final data = jsonDecode(result.data) as Map<String, dynamic>;
    expect(data['lookups'], isEmpty);
    expect(data['dpd_error'], contains('not installed'));
    // The note goes to the model and to MCP clients: no path of the user's.
    expect(data['dpd_error'], isNot(contains(dir.path)));

    final batch = await missing.read(aiQaToolServiceProvider).getDictionaryBatch({
      'terms': ['dhamma'],
    });
    final entries = jsonDecode(batch.data) as List<dynamic>;
    expect((entries.single as Map)['dpd_error'], contains('not installed'));
  });
}

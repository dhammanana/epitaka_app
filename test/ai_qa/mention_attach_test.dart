/// Tests for @ mention selection: attaching an item records the consumed
/// `@query` token so the chat screen can strip it from the input field.
library;

import 'package:epitaka/features/ai_qa/models/heading_attachment.dart';
import 'package:epitaka/features/ai_qa/providers/mention_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MentionSearchResult _fake(String title) => MentionSearchResult(
  bookId: 'dn1',
  paraId: 1,
  title: title,
  bookName: 'Dīgha Nikāya',
  path: 'dn1/$title',
);

void main() {
  test('attachSelected attaches, records strip token, deactivates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(mentionSearchProvider.notifier);
    notifier.state = MentionSearchState(
      isActive: true,
      query: 'test',
      results: [_fake('Test Sutta')],
    );

    final attached = notifier.attachSelected(
      container.read(attachmentsProvider.notifier),
    );

    expect(attached, isNotNull);
    expect(attached!.title, 'Test Sutta');
    expect(container.read(attachmentsProvider), hasLength(1));

    final state = container.read(mentionSearchProvider);
    expect(state.isActive, isFalse);
    expect(state.stripToken, '@test');
    expect(state.stripEpoch, 1);
  });

  test('attachSelected with empty query records a bare @', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(mentionSearchProvider.notifier);
    notifier.state = MentionSearchState(
      isActive: true,
      results: [_fake('Test Sutta')],
    );

    notifier.attachSelected(container.read(attachmentsProvider.notifier));

    expect(container.read(mentionSearchProvider).stripToken, '@');
  });

  test('attachSelected returns null when nothing is selected', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(mentionSearchProvider.notifier);
    final attached = notifier.attachSelected(
      container.read(attachmentsProvider.notifier),
    );

    expect(attached, isNull);
    expect(container.read(attachmentsProvider), isEmpty);
    expect(container.read(mentionSearchProvider).stripEpoch, 0);
  });

  test('attachAt attaches the tapped row, not the highlighted one', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(mentionSearchProvider.notifier);
    notifier.state = MentionSearchState(
      isActive: true,
      query: 'sut',
      results: [_fake('First Sutta'), _fake('Second Sutta')],
      selectedIndex: 0,
    );

    final attached = notifier.attachAt(
      1,
      container.read(attachmentsProvider.notifier),
    );

    expect(attached!.title, 'Second Sutta');
    expect(container.read(attachmentsProvider).single.title, 'Second Sutta');
    expect(container.read(mentionSearchProvider).stripToken, '@sut');
  });
}

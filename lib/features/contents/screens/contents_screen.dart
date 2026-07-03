import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/contents_provider.dart';

/// Contents screen showing the table of contents for a book.
class ContentsScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;

  /// paraId the reader is currently at, used to highlight and auto-scroll
  /// to the current section when this screen opens.
  final int? currentParaId;

  const ContentsScreen({
    super.key,
    required this.bookId,
    this.bookName = '',
    this.currentParaId,
  });

  @override
  ConsumerState<ContentsScreen> createState() => _ContentsScreenState();
}

class _ContentsScreenState extends ConsumerState<ContentsScreen> {
  final _scrollController = ScrollController();
  bool _didScrollToCurrent = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Index of the last heading whose paraId is <= currentParaId — i.e. the
  /// section the reader is currently inside.
  int _currentHeadingIndex(List<dynamic> headings) {
    if (widget.currentParaId == null) return -1;
    int result = -1;
    for (var i = 0; i < headings.length; i++) {
      final paraId = headings[i].paraId as int?;
      if (paraId != null && paraId <= widget.currentParaId!) {
        result = i;
      } else {
        break;
      }
    }
    return result;
  }

  void _scrollToIndex(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    // Rough estimate: each row ~52px. Good enough for the initial jump;
    // ListView.builder rows aren't uniform-height-guaranteed.
    const estimatedItemHeight = 52.0;
    final target = (index * estimatedItemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final contentsAsync = ref.watch(contentsProvider(widget.bookId));
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: contentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (headings) {
          final currentIndex = _currentHeadingIndex(headings);

          if (!_didScrollToCurrent && currentIndex >= 0) {
            _didScrollToCurrent = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToIndex(currentIndex);
            });
          }

          return Column(
            children: [
              // Top bar with close
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.marginMobile,
                    AppDimensions.sm,
                    AppDimensions.marginMobile,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contents',
                        style: AppTypography.headlineSmall.copyWith(
                          color: colors.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: colors.onSurfaceVariant,
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: colors.outlineVariant, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  itemCount: headings.length,
                  itemBuilder: (context, index) {
                    final heading = headings[index];
                    final indent = (heading.level ?? 1).clamp(1, 5) - 1;
                    final isCurrent = index == currentIndex;

                    return Padding(
                      padding:
                          EdgeInsets.only(left: indent * AppDimensions.md),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? colors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: InkWell(
                          onTap: () {
                            // Update current tab to jump to this heading
                            // rather than opening a new tab
                            final tabsState = ref.read(readerTabsProvider);
                            final existingIndex = tabsState.tabs
                                .indexWhere((t) => t.bookId == widget.bookId);
                            if (existingIndex >= 0) {
                              // Update existing tab's initialParaId to trigger scroll
                              ref
                                  .read(readerTabsProvider.notifier)
                                  .openTab(ReaderTabInfo(
                                    bookId: widget.bookId,
                                    bookName: widget.bookName,
                                    initialParaId: heading.paraId,
                                  ));
                            } else {
                              // Open a new tab for this book
                              ref
                                  .read(readerTabsProvider.notifier)
                                  .openTab(ReaderTabInfo(
                                    bookId: widget.bookId,
                                    bookName: widget.bookName,
                                    initialParaId: heading.paraId,
                                  ));
                            }
                            context.pop();
                          },
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: AppDimensions.md,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    heading.title ?? 'Untitled',
                                    style: AppTypography.headlineSmall
                                        .copyWith(
                                      fontSize: 18,
                                      color: isCurrent
                                          ? colors.primary
                                          : colors.onSurface,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isCurrent
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  size: 16,
                                  color: isCurrent
                                      ? colors.primary
                                      : colors.outlineVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
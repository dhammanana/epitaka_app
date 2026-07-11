import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/pali_text.dart';
import '../providers/reader_tabs_provider.dart';
import '../services/jump_service.dart';

/// Shows a bottom sheet with two tabs:
/// 1. Connected Books — Jump to mūla/aṭṭhakathā/ṭīkā at the current section.
/// 2. Jump to Page — Jump to a specific page in the current book.
Future<void> showJumpSheet(
  BuildContext context, {
  required String bookId,
  required String bookName,
  required int currentParaId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JumpSheet(
      bookId: bookId,
      bookName: bookName,
      currentParaId: currentParaId,
    ),
  );
}

class _JumpSheet extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;
  final int currentParaId;

  const _JumpSheet({
    required this.bookId,
    required this.bookName,
    required this.currentParaId,
  });

  @override
  ConsumerState<_JumpSheet> createState() => _JumpSheetState();
}

class _JumpSheetState extends ConsumerState<_JumpSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Tab 1: Connected Books ─────────────────────────────────────
  List<ConnectedBookJump>? _connectedJumps;
  bool _isLoadingConnections = true;
  String? _connectionError;

  // ── Tab 2: Jump to Page ────────────────────────────────────────
  final _pageInputController = TextEditingController();
  String _selectedPageSystem = 'vri';
  bool _isJumping = false;

  static const _pageSystems = [
    ('vri', 'VRI'),
    ('pts', 'PTS'),
    ('thai', 'Thai'),
    ('my', 'Myanmar'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConnectedJumps();
  }

  Future<void> _loadConnectedJumps() async {
    try {
      final db = await ref.read(epitakaDbProvider.future);
      final service = JumpService(db);
      final jumps = await service.getConnectedJumps(
        widget.bookId,
        widget.currentParaId,
      );
      if (mounted) {
        setState(() {
          _connectedJumps = jumps;
          _isLoadingConnections = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionError = e.toString();
          _isLoadingConnections = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pageSystemLabel = _pageSystemLabel(_selectedPageSystem);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.65,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // ── Tab bar ────────────────────────────────────────────
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 18),
                    SizedBox(width: 6),
                    Text('Connected Books'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.numbers, size: 18),
                    SizedBox(width: 6),
                    Text('Jump to Page'),
                  ],
                ),
              ),
            ],
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurfaceVariant,
            indicatorColor: colors.primary,
          ),

          // ── Tab content ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConnectedBooksTab(colors),
                _buildPageJumpTab(colors, pageSystemLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Connected Books ────────────────────────────────────────

  Widget _buildConnectedBooksTab(ColorScheme colors) {
    if (_isLoadingConnections) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_connectionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error loading connected books.\n$_connectionError',
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_connectedJumps == null || _connectedJumps!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off, size: 48, color: colors.outlineVariant),
              const SizedBox(height: 16),
              Text(
                'No connected books found for this section.',
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        32,
      ),
      itemCount: _connectedJumps!.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: colors.outlineVariant),
      itemBuilder: (context, index) {
        final jump = _connectedJumps![index];
        return _ConnectedBookTile(
          jump: jump,
          colors: colors,
          onTap: () => _openBook(jump),
        );
      },
    );
  }

  void _openBook(ConnectedBookJump jump) {
    // Open the connected book in a new reader tab
    ref.read(readerTabsProvider.notifier).openTab(
      ReaderTabInfo(
        bookId: jump.bookId,
        bookName: jump.bookName,
        initialParaId: jump.paraId,
      ),
    );
    Navigator.of(context).pop();
    context.push('/reader');
  }

  // ── Tab 2: Jump to Page ──────────────────────────────────────────

  Widget _buildPageJumpTab(
    ColorScheme colors,
    String pageSystemLabel,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.lg,
        AppDimensions.marginMobile,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page numbering system selector ─────────────────────
          Text(
            'Page Numbering System',
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // System dropdown
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPageSystem,
                isExpanded: true,
                items: _pageSystems.map((entry) {
                  return DropdownMenuItem(
                    value: entry.$1,
                    child: Text(entry.$2),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedPageSystem = v);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Page number input ─────────────────────────────────
          Text(
            'Page Number',
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pageInputController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.go,
            decoration: InputDecoration(
              hintText: 'e.g. 10 or 1.10',
              hintStyle: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                icon: _isJumping
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Icon(Icons.arrow_forward, color: colors.primary),
                onPressed: _isJumping ? null : _jumpToPage,
              ),
            ),
            onSubmitted: _isJumping ? null : (_) => _jumpToPage(),
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Tip: If pages are numbered like "1.3", you can type just "3" '
            'to jump to page 1.3.',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _jumpToPage() async {
    final input = _pageInputController.text.trim();
    if (input.isEmpty) return;

    setState(() => _isJumping = true);

    try {
      final db = await ref.read(epitakaDbProvider.future);
      final service = JumpService(db);
      final column = _pageColumnName(_selectedPageSystem);

      final paraId = await service.findParaIdByPage(
        widget.bookId,
        input,
        column,
      );

      if (!mounted) return;

      if (paraId != null) {
        // Open the current book at the found paragraph
        ref.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: widget.bookId,
            bookName: widget.bookName,
            initialParaId: paraId,
          ),
        );
        Navigator.of(context).pop();
        context.push('/reader');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Page "$input" not found in this book.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isJumping = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isJumping = false);
    }
  }

  String _pageSystemLabel(String code) {
    for (final entry in _pageSystems) {
      if (entry.$1 == code) return entry.$2;
    }
    return 'VRI';
  }

  String _pageColumnName(String system) {
    switch (system) {
      case 'vri':
        return 'vripage';
      case 'pts':
        return 'ptspage';
      case 'thai':
        return 'thaipage';
      case 'my':
        return 'mypage';
      default:
        return 'vripage';
    }
  }
}

/// Tile for a single connected book result.
/// Uses a [ConsumerWidget] so it can access the Pāli script setting
/// to convert the book name automatically.
class _ConnectedBookTile extends ConsumerWidget {
  final ConnectedBookJump jump;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _ConnectedBookTile({
    required this.jump,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Book type indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu_book,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Book info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PaliText(
                    jump.bookName,
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Section ${jump.title}',
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          jump.typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: colors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

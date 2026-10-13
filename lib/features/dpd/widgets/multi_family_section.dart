import 'package:flutter/material.dart';

import '../models/family_data.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import 'entry_content.dart';
import 'family_table.dart';
import '../utils/text_filters.dart';

/// A single sub-family entry for multi-family display.
class FamilySubSection {
  const FamilySubSection({
    required this.key,
    required this.header,
    required this.entries,
    required this.footerConfig,
  });

  final String key;
  final Widget header;
  final List<FamilyEntry> entries;
  final FamilyFooterConfig footerConfig;
}

/// Renders multiple sub-families (for compound families or sets).
///
/// Single sub-family: delegates to [FamilyTableWidget].
/// Multiple sub-families: one [DpdSectionContainer] with a "jump to" nav at
/// the top, all sub-family tables inside, then ONE back-to-top and ONE footer
/// at the very bottom — matching the webapp layout.
class MultiFamilySection extends StatefulWidget {
  const MultiFamilySection({super.key, required this.subSections});

  final List<FamilySubSection> subSections;

  @override
  State<MultiFamilySection> createState() => _MultiFamilySectionState();
}

class _MultiFamilySectionState extends State<MultiFamilySection> {
  final _topKey = GlobalKey();
  final List<GlobalKey> _sectionKeys = [];

  @override
  void initState() {
    super.initState();
    _sectionKeys.addAll(
      List.generate(widget.subSections.length, (_) => GlobalKey()),
    );
  }

  void _scrollToSection(int index) {
    final ctx = _sectionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  void _scrollToTop() {
    final ctx = _topKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subSections.length == 1) {
      final s = widget.subSections.first;
      return FamilyTableWidget(
        header: s.header,
        entries: s.entries,
        footerConfig: s.footerConfig,
      );
    }

    return DpdSectionContainer(
      child: Padding(
        padding: DpdColors.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Jump-to nav — scroll target for back-to-top
            KeyedSubtree(
              key: _topKey,
              child: _JumpToNav(
                keys: widget.subSections.map((s) => s.key).toList(),
                onTap: _scrollToSection,
              ),
            ),
            const SizedBox(height: 8),

            // Sub-family sections — headers + tables only, no footer between them
            for (int i = 0; i < widget.subSections.length; i++) ...[
              Container(
                key: _sectionKeys[i],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeadingDoublelined(
                      child: i > 0
                          ? _maybeCloneWithJump(
                              context,
                              widget.subSections[i].header,
                              _scrollToTop,
                            )
                          : widget.subSections[i].header,
                    ),
                    const SizedBox(height: 8),
                    if (widget.subSections[i].entries.isNotEmpty)
                      FamilyEntryTable(entries: widget.subSections[i].entries),
                  ],
                ),
              ),
              if (i < widget.subSections.length - 1) const SizedBox(height: 16),
            ],

            // Single back-to-top + single footer at the very bottom
            const SizedBox(height: 8),
            _BackToTopLink(onTap: _scrollToTop),
            DpdFooter(
              messagePrefix:
                  widget.subSections.first.footerConfig.messagePrefix,
              linkText: widget.subSections.first.footerConfig.linkText,
              feedbackType: widget.subSections.first.footerConfig.feedbackType,
              word: widget.subSections.first.footerConfig.word,
              headwordId: widget.subSections.first.footerConfig.headwordId,
            ),
          ],
        ),
      ),
    );
  }
}

/// Clones a Text.rich header with a jump-to-top icon appended.
/// Returns the header unchanged if it is not a Text.rich widget.
Widget _maybeCloneWithJump(
  BuildContext context,
  Widget header,
  VoidCallback onJump,
) {
  if (header is! Text || header.textSpan == null) return header;
  final oldSpan = header.textSpan! as TextSpan;
  final color = Theme.of(context).colorScheme.primary;
  return Text.rich(
    TextSpan(
      style: oldSpan.style,
      children: [
        ...oldSpan.children ?? [],
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onJump,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.keyboard_double_arrow_up,
                  size: 14,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _JumpToNav extends StatelessWidget {
  const _JumpToNav({required this.keys, required this.onTap});

  final List<String> keys;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'jump to: ',
          style: TextStyle(fontSize: 12, color: context.palette.primaryText),
        ),
        for (int i = 0; i < keys.length; i++)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SelectionContainer.disabled(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Text(
                  context.nigg(
                    i < keys.length - 1 ? '${keys[i]}, ' : keys[i],
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.primaryText,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeadingDoublelined extends StatelessWidget {
  const _HeadingDoublelined({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.palette.primary, width: 1),
          bottom: BorderSide(color: context.palette.primary, width: 1),
        ),
      ),
      child: child,
    );
  }
}

class _BackToTopLink extends StatelessWidget {
  const _BackToTopLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SelectionContainer.disabled(
        child: GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_double_arrow_up, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                'back to top',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

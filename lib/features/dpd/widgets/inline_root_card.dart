import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_database.dart';
import '../models/family_data.dart';
import '../providers/family_provider.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import 'entry_content.dart';
import 'family_section_builders.dart';
import 'family_table.dart';
import 'feedback_type.dart';
import 'root_info_table.dart';
import 'root_matrix_table.dart';
import '../utils/text_filters.dart';

class InlineRootCard extends ConsumerStatefulWidget {
  const InlineRootCard({super.key, required this.rwf});

  final RootWithFamilies rwf;

  @override
  ConsumerState<InlineRootCard> createState() => _InlineRootCardState();
}

class _InlineRootCardState extends ConsumerState<InlineRootCard> {
  String? _activeSection;

  String get _rootClean => widget.rwf.root.root.replaceAll('√', '');

  void _toggle(String section) {
    setState(() {
      _activeSection = _activeSection == section ? null : section;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Eagerly start loading bases and root matrix in background
    ref.watch(basesForRootProvider(widget.rwf.root.root));
    ref.watch(rootMatrixProvider(widget.rwf.root.root));

    final theme = Theme.of(context);
    final root = widget.rwf.root;
    final families = widget.rwf.families;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    final boldStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);
    final grayStyle = baseStyle?.copyWith(color: context.palette.gray);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 1),
            child: Text(
              context.nigg('root: $_rootClean'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Summary box
          _RootSummaryBox(
            rootClean: _rootClean,
            root: root,
            count: widget.rwf.count,
            baseStyle: baseStyle,
            boldStyle: boldStyle,
            grayStyle: grayStyle,
          ),

          // Button row
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
            child: Wrap(
              children: [
                if (true)
                  DpdSectionButton(
                    label: 'root info',
                    isActive: _activeSection == 'info',
                    onTap: () => _toggle('info'),
                  ),
                if ((root.rootCount ?? 0) > 0)
                  DpdSectionButton(
                    label: 'root matrix',
                    isActive: _activeSection == 'matrix',
                    onTap: () => _toggle('matrix'),
                  ),
                for (final fam in families)
                  DpdSectionButton(
                    label: context.nigg(fam.rootFamily),
                    isActive: _activeSection == fam.rootFamilyKey,
                    onTap: () => _toggle(fam.rootFamilyKey),
                  ),
              ],
            ),
          ),

          // Content sections
          if (_activeSection == 'info' && true) _buildRootInfoSection(),

          if (_activeSection == 'matrix' && (root.rootCount ?? 0) > 0)
            _buildRootMatrixSection(),

          for (final fam in families)
            if (_activeSection == fam.rootFamilyKey) _buildFamilySection(fam),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRootInfoSection() {
    final root = widget.rwf.root;
    final basesAsync = ref.watch(basesForRootProvider(root.root));
    final bases = basesAsync.whenOrNull(data: (b) => b);

    return RootInfoTable(root: root, bases: bases);
  }

  Widget _buildRootMatrixSection() {
    final root = widget.rwf.root;
    final matrixAsync = ref.watch(rootMatrixProvider(root.root));
    final matrix = matrixAsync.whenOrNull(data: (m) => m);

    if (matrix != null) {
      return RootMatrixTable(root: root.root, data: matrix);
    } else {
      return DpdSectionContainer(
        child: Padding(
          padding: DpdColors.sectionPadding,
          child: const CircularProgressIndicator(),
        ),
      );
    }
  }

  Widget _buildFamilySection(FamilyRootData fam) {
    return FamilyTableWidget(
      header: buildRootFamilyHeader(context, fam),
      entries: parseFamilyData(fam.data),
      footerConfig: _buildRootFooterConfig(fam),
    );
  }

  FamilyFooterConfig _buildRootFooterConfig(FamilyRootData fam) {
    return FamilyFooterConfig(
      messagePrefix: 'Something out of place?',
      linkText: 'Report it here',
      feedbackType: FeedbackType.rootFamily,
      word: widget.rwf.root.root,
    );
  }
}

class _RootSummaryBox extends StatelessWidget {
  const _RootSummaryBox({
    required this.rootClean,
    required this.root,
    required this.count,
    required this.baseStyle,
    required this.boldStyle,
    required this.grayStyle,
  });

  final String rootClean;
  final DpdRoot root;
  final int count;
  final TextStyle? baseStyle;
  final TextStyle? boldStyle;
  final TextStyle? grayStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 2),
        borderRadius: DpdColors.borderRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'root. '),
            TextSpan(text: context.nigg(rootClean), style: boldStyle),
            if (root.rootHasVerb.isNotEmpty)
              TextSpan(
                text: root.rootHasVerb,
                style: baseStyle?.copyWith(
                  fontSize: (baseStyle?.fontSize ?? 14) * 0.7,
                  fontFeatures: [const FontFeature.superscripts()],
                ),
              ),
            TextSpan(text: context.nigg(' ${root.rootGroup} ')),
            TextSpan(text: context.nigg(root.rootSign)),
            TextSpan(text: context.nigg(' (${root.rootMeaning})')),
            TextSpan(text: ' $count', style: grayStyle),
          ],
        ),
      ),
    );
  }
}

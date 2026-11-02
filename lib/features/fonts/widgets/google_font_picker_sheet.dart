import 'package:flutter/material.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/google_font_service.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';

/// Opens the reading-font picker: the three bundled families first, then the
/// whole Google Fonts catalog behind a search field.
///
/// Each family is listed in its own face, so the choice is made by eye rather
/// than by name. Returns the picked family, or null when dismissed.
Future<ReadingFontFamily?> showReadingFontPicker(
  BuildContext context, {
  required ReadingFontFamily current,
  required String sample,
}) {
  return showModalBottomSheet<ReadingFontFamily>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ReadingFontPicker(current: current, sample: sample),
  );
}

class _ReadingFontPicker extends StatefulWidget {
  final ReadingFontFamily current;
  final String sample;

  const _ReadingFontPicker({required this.current, required this.sample});

  @override
  State<_ReadingFontPicker> createState() => _ReadingFontPickerState();
}

class _ReadingFontPickerState extends State<_ReadingFontPicker> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    // The bundled families never scroll away: they are the offline-safe
    // fallback when the catalog cannot be reached.
    final showBundled = _query.trim().isEmpty;
    final bundledCount = showBundled ? ReadingFontFamily.values.length : 0;
    final headerCount = showBundled ? 1 : 0;
    final offset = bundledCount + headerCount;
    final fonts = GoogleFontService.instance.search(_query);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.sm,
              AppDimensions.md,
              AppDimensions.sm,
            ),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: loc.searchFonts,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: loc.clear,
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: fonts.isEmpty && !showBundled
                ? Center(
                    child: Text(
                      loc.noFontsFound,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.md,
                      0,
                      AppDimensions.md,
                      AppDimensions.lg,
                    ),
                    itemCount: offset + fonts.length,
                    itemBuilder: (context, i) {
                      if (i < bundledCount) {
                        final family = ReadingFontFamily.values[i];
                        return _FontTile(
                          label: family.label,
                          current: widget.current,
                          family: family,
                          sample: widget.sample,
                        );
                      }
                      if (i < offset) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
                          child: Text(
                            'GOOGLE FONTS',
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.4,
                            ),
                          ),
                        );
                      }
                      final name = fonts[i - offset];
                      return _FontTile(
                        label: name,
                        current: widget.current,
                        family: ReadingFontFamily.google(name),
                        sample: widget.sample,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// One family row: the name drawn in that family, ticked when in use.
///
/// A Google family's preview is normally just its name in its own face so the
/// list stays cheap; the selected one also shows [sample] in the reading
/// script, which reveals missing glyphs before the sheet is dismissed.
class _FontTile extends StatelessWidget {
  final String label;
  final ReadingFontFamily family;
  final ReadingFontFamily current;
  final String sample;

  const _FontTile({
    required this.label,
    required this.family,
    required this.current,
    required this.sample,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = family == current;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).pop(family),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: family.fontFamily,
                      fontSize: 17,
                      color: selected ? colors.primary : colors.onSurface,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: 2),
                    Text(
                      sample,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: family.fontFamily,
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_localizations.dart';

/// Absolute upper bound for a user-typed TTS speed. Users can go as high
/// as they like below this (the slider's old 8× cap is gone); beyond it
/// audio is pure noise and the engine times out.
const double kMaxTtsSpeed = 20.0;

/// A TTS speed control combining two adjustment styles:
///
/// 1. **− / + buttons** — fine ±[step] nudges.
/// 2. **Tappable value chip** — opens a dialog to type any exact number
///    up to [kMaxTtsSpeed].
///
/// There is intentionally no slider: a slider's fixed range capped the
/// speed, and it offered no way to enter a precise value.
class TtsSpeedControl extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;

  /// Lowest meaningful speed; the − button stops here. 0.1 for Pāli,
  /// 0.5 for translation.
  final double min;
  final ColorScheme colors;

  /// Compact layout (two rows) for the reader's TTS controls card.
  final bool compact;

  /// Size of each − / + nudge.
  final double step;

  final ValueChanged<double> onChanged;

  const TtsSpeedControl({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.colors,
    required this.onChanged,
    this.step = 0.1,
    this.compact = false,
  });

  static String _fmt(double v) => v.toStringAsFixed(1);

  void _bump(double delta) =>
      onChanged((value + delta).clamp(min, kMaxTtsSpeed).toDouble());

  Future<void> _editValue(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: _fmt(value));
    final current = value;
    String? errorText;

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('$label — ${loc.ttsSpeed}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              // Digits + one decimal separator; the cap is validated on
              // submit so typing "15" isn't blocked mid-edit.
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,2}([.,]\d{0,2})?$'),
              ),
            ],
            decoration: InputDecoration(
              hintText: '1.0',
              suffixText: '×',
              errorText: errorText,
            ),
            onSubmitted: (_) =>
                Navigator.of(dialogContext).pop(_parse(controller.text)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () {
                final parsed = _parse(controller.text);
                if (parsed == null) {
                  setDialogState(
                    () => errorText = loc.ttsSpeedRangeHint(kMaxTtsSpeed),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(parsed);
              },
              child: Text(loc.ok),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final clamped = result.clamp(min, kMaxTtsSpeed).toDouble();
    // Only notify when the parsed value differs from the current one so
    // tapping the chip and dismissing doesn't trigger a settings write.
    if (clamped != current) onChanged(clamped);
  }

  /// Parse a typed speed value; null when invalid (empty, >2 decimals
  /// blocked by the formatter, or above [kMaxTtsSpeed]).
  static double? _parse(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > kMaxTtsSpeed) return null;
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      minimumSize: const Size(32, 32),
      padding: EdgeInsets.zero,
    );

    final stepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '-$step',
          onPressed: value > min ? () => _bump(-step) : null,
          icon: const Icon(Icons.remove, size: 16),
          style: buttonStyle,
        ),
        InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: () => _editValue(context),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              '${_fmt(value)}×',
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '+$step',
          onPressed: value < kMaxTtsSpeed ? () => _bump(step) : null,
          icon: const Icon(Icons.add, size: 16),
          style: buttonStyle,
        ),
      ],
    );

    if (compact) {
      // Single row — fits the ~280px reader card with no slider to overflow.
      return Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurface,
                fontSize: 12,
              ),
            ),
          ),
          stepper,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          stepper,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dpd/providers/lookup_history.dart';

/// The back and forward arrows beside the search field. Each is greyed out
/// when there is nowhere to go, and its tooltip names the word it goes to.
/// The sheet and the panel draw them the same size.
class LookupHistoryButtons extends ConsumerWidget {
  const LookupHistoryButtons({
    super.key,
    required this.onBack,
    required this.onForward,
  });

  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(lookupHistoryProvider);
    final back = history.backWord;
    final forward = history.forwardWord;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 22,
          visualDensity: VisualDensity.compact,
          tooltip: back == null ? null : '← $back',
          onPressed: back == null ? null : onBack,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          iconSize: 22,
          visualDensity: VisualDensity.compact,
          tooltip: forward == null ? null : '$forward →',
          onPressed: forward == null ? null : onForward,
        ),
      ],
    );
  }
}

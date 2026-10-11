// lib/features/guide/models/feature_guide_section.dart
//
// Data model for the Feature Guide — the new-user instructions that explain
// what ePitaka can do (reader toolbar, context menu, settings, AI, …).
//
// Text is stored as l10n keys (the English source strings) so the guide is
// localized for free through the existing AppStrings tables.

import 'package:flutter/material.dart';

import '../../../core/utils/platform_info.dart';

/// One instruction step inside a [FeatureGuideSection].
///
/// [icon] mirrors the icon of the real toolbar button / screen element so
/// users can recognise the feature at a glance — no need to read numbers.
class FeatureGuideStep {
  final IconData icon;

  /// l10n key for the instruction text.
  final String textKey;

  /// True for a step about speech; it is left out where speech is unsupported.
  final bool needsTts;

  const FeatureGuideStep({
    required this.icon,
    required this.textKey,
    this.needsTts = false,
  });
}

/// A group of related features shown in the Feature Guide.
class FeatureGuideSection {
  final String id;
  final IconData icon;

  /// l10n key for the section title (e.g. 'Reader Toolbar').
  final String titleKey;

  /// l10n key for the one-line section description.
  final String descKey;

  /// The instruction steps, in order.
  final List<FeatureGuideStep> steps;

  /// [steps] without the ones this platform cannot use.
  List<FeatureGuideStep> get visibleSteps => [
    for (final s in steps)
      if (!s.needsTts || PlatformInfo.isTtsSupported) s,
  ];

  const FeatureGuideSection({
    required this.id,
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.steps,
  });
}

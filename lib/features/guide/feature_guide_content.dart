// lib/features/guide/feature_guide_content.dart
//
// The Feature Guide content — new-user instructions grouped by feature area.
//
// Text lives in the l10n tables: every string below is a key whose value is
// the localized text (keys are the English source strings). Add/translate
// them in `core/utils/l10n/*.dart`; anything missing falls back to English.
//
// Every step also carries the icon of the real toolbar button / screen
// element it describes, so users can recognise the feature at a glance.

import 'package:flutter/material.dart';

import 'models/feature_guide_section.dart';

/// The feature guide sections, in display order.
/// Focus areas first: toolbar, context menu, settings, AI.
const List<FeatureGuideSection> kFeatureGuideSections = [
  // ── Reader Toolbar ──────────────────────────────────────────────────
  FeatureGuideSection(
    id: 'toolbar',
    icon: Icons.bolt_outlined,
    titleKey: 'Reader Toolbar',
    descKey:
        'The floating toolbar at the bottom of the reader puts every action one tap away.',
    steps: [
      FeatureGuideStep(
        icon: Icons.format_list_bulleted,
        textKey: 'Contents — jump between sections from the table of contents.',
      ),
      FeatureGuideStep(
        icon: Icons.search,
        textKey: 'Search — find a word or phrase inside the current book.',
      ),
      FeatureGuideStep(
        icon: Icons.menu_book,
        textKey: 'Dictionary — look up any Pāli word instantly.',
      ),
      FeatureGuideStep(
        icon: Icons.open_in_new,
        textKey: 'Jump — go to a page number or a connected book.',
      ),
      FeatureGuideStep(
        icon: Icons.view_headline,
        textKey:
            'Display layout — switch between hide-translation, line-by-line and side-by-side views.',
      ),
      FeatureGuideStep(
        icon: Icons.volume_up,
        textKey:
            'Listen — read the passage aloud with text-to-speech; tap again to stop.',
      ),
      FeatureGuideStep(
        icon: Icons.bookmark,
        textKey:
            'Bookmark — save your place and return to it later from the Library.',
      ),
    ],
  ),

  // ── Context Menu (selection toolbar) ────────────────────────────────
  FeatureGuideSection(
    id: 'contextMenu',
    icon: Icons.text_fields,
    titleKey: 'Context Menu',
    descKey:
        'Select any text in the reader and a toolbar of smart actions appears above it.',
    steps: [
      FeatureGuideStep(
        icon: Icons.mouse,
        textKey: 'Select text — tap and drag, or double-tap a word.',
      ),
      FeatureGuideStep(
        icon: Icons.copy,
        textKey: 'Copy — copy the selection as plain text.',
      ),
      FeatureGuideStep(
        icon: Icons.format_quote,
        textKey: 'Excerpt — copy with a formatted citation.',
      ),
      FeatureGuideStep(
        icon: Icons.link,
        textKey: 'Copy Link — copy a shareable link to this exact passage.',
      ),
      FeatureGuideStep(
        icon: Icons.menu_book,
        textKey: 'Dictionary — look up the selected word.',
      ),
      FeatureGuideStep(
        icon: Icons.auto_awesome,
        textKey: 'Explain — ask Vimaṃsa AI to explain the selection.',
      ),
      FeatureGuideStep(
        icon: Icons.notes,
        textKey: 'Summarize Ch. — summarize the current chapter with AI.',
      ),
      FeatureGuideStep(
        icon: Icons.share,
        textKey: 'Share — share the selection via the system share sheet.',
      ),
      FeatureGuideStep(
        icon: Icons.tune,
        textKey:
            'Customize — Settings → Context Menu lets you reorder, hide, or add apps and AI prompts.',
      ),
    ],
  ),

  // ── Settings ────────────────────────────────────────────────────────
  FeatureGuideSection(
    id: 'settings',
    icon: Icons.settings_outlined,
    titleKey: 'Settings',
    descKey: 'Everything you need to personalize ePitaka.',
    steps: [
      FeatureGuideStep(
        icon: Icons.language,
        textKey:
            'Language & script — choose the UI language and the Pāli script (Roman, Devanagari, Sinhala, Myanmar, Thai…).',
      ),
      FeatureGuideStep(
        icon: Icons.palette,
        textKey: 'Appearance — themes, accent color and reading colors.',
      ),
      FeatureGuideStep(
        icon: Icons.download,
        textKey:
            'Translations & Downloads — download, update and reorder translation databases.',
      ),
      FeatureGuideStep(
        icon: Icons.view_agenda,
        textKey:
            'Reading Options — layout, page numbering, quote format and auto-scroll.',
      ),
      FeatureGuideStep(
        icon: Icons.record_voice_over,
        textKey:
            'Text-to-Speech — voice, speed, pitch and word replacements.',
      ),
      FeatureGuideStep(
        icon: Icons.menu_book,
        textKey: 'Dictionaries — enable, disable and reorder dictionaries.',
      ),
      FeatureGuideStep(
        icon: Icons.auto_awesome,
        textKey: 'AI Q&A — enter your API key and pick models for Vimaṃsa.',
      ),
    ],
  ),

  // ── AI (Vimaṃsa) ────────────────────────────────────────────────────
  FeatureGuideSection(
    id: 'ai',
    icon: Icons.auto_awesome_outlined,
    titleKey: 'AI — Vimaṃsa',
    descKey:
        'Ask the AI about the Tipiṭaka. It searches the Canon and answers with citations.',
    steps: [
      FeatureGuideStep(
        icon: Icons.question_answer,
        textKey: 'Ask a question — open Vimaṃsa from the menu and ask anything.',
      ),
      FeatureGuideStep(
        icon: Icons.auto_awesome,
        textKey:
            'Explain — select text in the reader and tap Explain for a commentary-grounded explanation.',
      ),
      FeatureGuideStep(
        icon: Icons.notes,
        textKey:
            'Summarize — tap Summarize Ch. to get an overview of the current chapter.',
      ),
      FeatureGuideStep(
        icon: Icons.alternate_email,
        textKey:
            'Attach a passage — type @ to attach a sutta or heading to your question.',
      ),
      FeatureGuideStep(
        icon: Icons.history,
        textKey:
            'Chat history — your conversations are saved; continue them anytime.',
      ),
      FeatureGuideStep(
        icon: Icons.smart_toy_outlined,
        textKey:
            'Custom prompts — add your own AI prompts in Settings → Context Menu; use {selectedText} as a placeholder.',
      ),
    ],
  ),
];

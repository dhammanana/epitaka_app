import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:epitaka/features/dictionary/providers/dictionary_expanded_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_collapsible_card.dart';

import '../providers/mdx_lookup_providers.dart';
import '../providers/mdx_web_providers.dart';
import '../services/mdx_text.dart';
import 'mdx_webview.dart';

class MdxDefinitionSection extends ConsumerWidget {
  final String dictId;
  final String dictTitle;
  final String searchWord;
  final void Function(String word)? onEntryTap;
  const MdxDefinitionSection({
    super.key,
    required this.dictId,
    required this.dictTitle,
    required this.searchWord,
    this.onEntryTap,
  });

  String get _cardKey => 'mdx_$dictId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final expanded = ref.watch(dictionaryExpandedFamilyProvider(_cardKey));
    // Collapsed: header only, no definition fetch.
    if (!expanded) {
      return DictionaryCollapsibleCard(
        dictionaryKey: _cardKey,
        title: dictTitle,
        icon: Icons.book,
        colors: colors,
        child: const SizedBox.shrink(),
      );
    }
    // Real WebView rendering (Ciyue-style) where supported; legacy
    // flutter_html stays for Linux/web.
    if (MdxWebViewBody.isSupported) {
      return _MdxWebDocSection(
        dictId: dictId,
        dictTitle: dictTitle,
        searchWord: searchWord,
        onEntryTap: onEntryTap,
      );
    }
    final baseStyle = Theme.of(context).textTheme.bodyMedium!;
    final defs = ref.watch(
      mdxDefinitionsProvider(MdxDefKey(dictId, searchWord)),
    );
    return defs.when(
      loading: () => DictionaryCollapsibleCard(
        dictionaryKey: _cardKey,
        title: dictTitle,
        icon: Icons.book,
        colors: colors,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => DictionaryCollapsibleCard(
        dictionaryKey: _cardKey,
        title: dictTitle,
        icon: Icons.book,
        colors: colors,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.toString(),
                style: baseStyle.copyWith(color: colors.error, fontSize: 13),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                onPressed: () => ref.invalidate(
                  mdxDefinitionsProvider(MdxDefKey(dictId, searchWord)),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (list) {
        // No entry in this dictionary → hide the section entirely.
        if (list.isEmpty) return const SizedBox.shrink();
        return DictionaryCollapsibleCard(
          dictionaryKey: _cardKey,
          title: dictTitle,
          icon: Icons.book,
          colors: colors,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  Html(
                    data: mdxSanitize(list[i]),
                    extensions: [MdxImageExtension(dictId)],
                    onLinkTap: (url, _, _) => _handleLinkTap(url, onEntryTap),
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(baseStyle.fontSize ?? 14),
                        lineHeight: const LineHeight(1.4),
                        color: baseStyle.color,
                      ),
                      'p': Style(margin: Margins.only(bottom: 4)),
                      'b': Style(fontWeight: FontWeight.bold),
                      'i': Style(fontStyle: FontStyle.italic),
                      'ul': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.only(left: 16),
                      ),
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// WebView branch of the definition section: watches the full HTML document
/// provider and embeds one auto-height WebView per (dictionary, word).
/// The caller ([MdxDefinitionSection]) already guarantees expanded state,
/// so this only runs while expanded (lazy load).
class _MdxWebDocSection extends ConsumerWidget {
  final String dictId;
  final String dictTitle;
  final String searchWord;
  final void Function(String word)? onEntryTap;

  const _MdxWebDocSection({
    required this.dictId,
    required this.dictTitle,
    required this.searchWord,
    this.onEntryTap,
  });

  String get _cardKey => 'mdx_$dictId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context).textTheme.bodyMedium!;
    final doc = ref.watch(mdxWebDocumentProvider(MdxDefKey(dictId, searchWord)));
    return doc.when(
      loading: () => DictionaryCollapsibleCard(
        dictionaryKey: _cardKey,
        title: dictTitle,
        icon: Icons.book,
        colors: colors,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => DictionaryCollapsibleCard(
        dictionaryKey: _cardKey,
        title: dictTitle,
        icon: Icons.book,
        colors: colors,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.toString(),
                style: baseStyle.copyWith(color: colors.error, fontSize: 13),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                onPressed: () => ref.invalidate(
                  mdxWebDocumentProvider(MdxDefKey(dictId, searchWord)),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (document) {
        // No entry in this dictionary → hide the section entirely.
        if (document.trim().isEmpty) return const SizedBox.shrink();
        return DictionaryCollapsibleCard(
          dictionaryKey: _cardKey,
          title: dictTitle,
          icon: Icons.book,
          colors: colors,
          child: ExcludeSemantics(
            child: MdxWebViewBody(
              key: ValueKey('mdx-web-$dictId-$searchWord'),
              dictId: dictId,
              word: searchWord,
              document: document,
              readResource: (key) => ref.read(
                mdxResourceProvider(MdxResKey(dictId, key)).future,
              ),
              onEntryTap: onEntryTap,
            ),
          ),
        );
      },
    );
  }
}

void _handleLinkTap(String? url, void Function(String word)? onEntryTap) {  if (url == null || url.trim().isEmpty) return;
  final trimmed = url.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('entry://')) {
    final word = Uri.decodeComponent(
      trimmed.substring('entry://'.length),
    ).split('#').first.split('?').first.trim();
    if (word.isNotEmpty) onEntryTap?.call(word);
    return;
  }
  if (lower.startsWith('sound://')) return;
}

class MdxImageExtension extends HtmlExtension {
  final String dictId;
  const MdxImageExtension(this.dictId);

  @override
  Set<String> get supportedTags => {'img'};

  @override
  bool matches(ExtensionContext context) {
    if (context.elementName != 'img') return false;
    final src = (context.attributes['src'] ?? '').trim().toLowerCase();
    if (src.isEmpty) return false;
    return !src.startsWith('http://') &&
        !src.startsWith('https://') &&
        !src.startsWith('data:') &&
        !src.startsWith('asset:') &&
        !src.startsWith('blob:') &&
        !src.startsWith('file://');
  }

  @override
  StyledElement prepare(
    ExtensionContext context,
    List<StyledElement> children,
  ) {
    final attrs = context.attributes;
    final width = double.tryParse(attrs['width'] ?? '');
    final height = double.tryParse(attrs['height'] ?? '');
    return ImageElement(
      name: context.elementName,
      children: children,
      style: Style(),
      node: context.node,
      elementId: context.id,
      src: attrs['src'] ?? '',
      alt: attrs['alt'],
      width: width != null ? Width(width) : null,
      height: height != null ? Height(height) : null,
    );
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final element = context.styledElement as ImageElement;
    final style = Style(
      width: element.width,
      height: element.height,
    ).merge(context.styledElement!.style);
    return WidgetSpan(
      child: CssBoxWidget(
        style: style,
        childIsReplaced: true,
        child: _MddImage(
          dictId: dictId,
          src: element.src,
          alt: element.alt,
          width: style.width?.value,
          height: style.height?.value,
        ),
      ),
    );
  }
}

class _MddImage extends ConsumerWidget {
  final String dictId;
  final String src;
  final String? alt;
  final double? width;
  final double? height;
  const _MddImage({
    required this.dictId,
    required this.src,
    this.alt,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final bytes = ref.watch(mdxResourceProvider(MdxResKey(dictId, src)));
    return bytes.when(
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => _missing(colors),
      data: (b) {
        if (b == null) return _missing(colors);
        return Image.memory(
          b,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => _missing(colors),
        );
      },
    );
  }

  Widget _missing(ColorScheme colors) {
    return Icon(
      Icons.broken_image_outlined,
      size: 18,
      color: colors.onSurfaceVariant,
      semanticLabel: alt ?? src,
    );
  }
}

class MdxSuggestionChips extends ConsumerWidget {
  final String query;
  final void Function(String word) onPick;
  const MdxSuggestionChips({
    super.key,
    required this.query,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sugg = ref.watch(mdxSuggestionsProvider(query));
    return sugg.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (words) {
        if (words.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final w in words.take(10))
              ActionChip(label: Text(w), onPressed: () => onPick(w)),
          ],
        );
      },
    );
  }
}

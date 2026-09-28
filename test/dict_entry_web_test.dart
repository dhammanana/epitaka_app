import 'package:epitaka/features/dictionary/services/dict_entry_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _primary = Color(0xff8f4900);
const _onSurface = Color(0xff221a14);
const _variant = Color(0xff544338);
const _outline = Color(0xffc8ad99);
const _container = Color(0xfffff1e9);

String _doc(List<String> bodies) => buildDictEntryDocument(
  bodies: bodies,
  fontSize: 14,
  fontFamily: 'Pyidaungsu',
  primary: _primary,
  onSurface: _onSurface,
  onSurfaceVariant: _variant,
  outlineVariant: _outline,
  containerLow: _container,
);

void main() {
  test('document covers all dictionary-table classes', () {
    final doc = _doc(const ['<p class="word">x</p>']);
    for (final cls in ['.word', '.gender', '.viggaha', '.definition', '.reference']) {
      expect(doc, contains(cls), reason: 'missing CSS for $cls');
    }
    expect(doc, contains('<p class="word">x</p>'));
    expect(doc, startsWith('<!DOCTYPE html>'));
  });

  test('document is transparent and theme tinted', () {
    final doc = _doc(const ['<p>hi</p>']);
    expect(doc, contains('background:transparent'));
    expect(doc, contains('color-scheme'));
    // Injected theme colours (lowercase hex without alpha).
    expect(doc, contains('#8f4900'));
    expect(doc, contains('#221a14'));
    expect(doc, contains('#544338'));
    expect(doc, contains('font-size:14.0px'));
    expect(doc, contains('Pyidaungsu'));
  });

  test('each body is wrapped as its own entry', () {
    final doc = _doc(const ['<p>a</p>', '<p>b</p>']);
    expect('<div class="dict-entry"><p>a</p></div>', contains('<div class="dict-entry">'));
    expect(doc.split('<div class="dict-entry">').length - 1, 2);
  });

  test('fallback styler highlights word, gender, viggaha and reference', () {
    String styled(String html) => applyDictEntryFallbackStyles(
      html,
      primary: _primary,
      onSurfaceVariant: _variant,
      containerLow: _container,
    );

    final word = styled('<p class="word">အဗ္ဘုတဓမ္မ</p>');
    expect(word, contains('style="'));
    expect(word, contains('#8f4900'));

    final gender = styled('<span class="gender">(ပု)</span>');
    expect(gender, contains('style="'));
    expect(gender, contains('#544338'));

    final viggaha = styled('<div class="viggaha"><p>[x+y]</p></div>');
    expect(viggaha, contains('style="'));
    expect(viggaha, contains('#fff1e9'));

    final ref = styled('<p class="reference">တိပိ၊၂၊၈၇၁</p>');
    expect(ref, contains('text-align:right'));

    // Plain tags and definition bodies pass through untouched.
    expect(styled('<p>plain</p>'), '<p>plain</p>');
    expect(styled('<div class="definition"><p>x</p></div>'), '<div class="definition"><p>x</p></div>');
  });

  test('fallback styler keeps pre-existing inline styles', () {
    final out = applyDictEntryFallbackStyles(
      '<p class="word" style="color:red">x</p>',
      primary: _primary,
      onSurfaceVariant: _variant,
      containerLow: _container,
    );
    expect(out, contains('color:red'));
    expect(out, isNot(contains('#8f4900')));
  });

  test('dictEntryNoResource always misses', () async {
    expect(await dictEntryNoResource('anything.css'), isNull);
  });
}

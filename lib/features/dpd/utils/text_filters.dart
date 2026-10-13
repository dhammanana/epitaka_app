import 'package:flutter/widgets.dart';

extension NiggahitaContext on BuildContext {
  /// ePitaka shows the dot form (ṃ), which is how the database stores it, so
  /// there is no circle-form choice to apply. The DPD app's widgets call this
  /// on every string; keeping the call keeps their files diffable.
  String nigg(String text) => text;
}

final _sandhiMark = RegExp(r"(?<=[\p{L}>])['-](?=[\p{L}<])", unicode: true);

/// Returns [text] without the apostrophes and hyphens that join two words
/// inside one written Pāḷi word (`kaṇṭh'oṭṭhajo`, `kata-akataṃ`) when [show]
/// is false.
///
/// Only a mark between two letters goes, and a tag edge (`kata-<b>akataṃ</b>`)
/// counts as a letter edge, so a quotation mark beside a space stays. The DPD
/// app's `filterApostrophe` removes every apostrophe, English possessives too;
/// this is for Pāḷi text only.
String filterSandhi(String text, {required bool show}) =>
    show ? text : text.replaceAll(_sandhiMark, '');

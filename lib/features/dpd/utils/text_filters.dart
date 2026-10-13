import 'package:flutter/widgets.dart';

extension NiggahitaContext on BuildContext {
  /// ePitaka shows the dot form (ṃ), which is how the database stores it, so
  /// there is no circle-form choice to apply. The DPD app's widgets call this
  /// on every string; keeping the call keeps their files diffable.
  String nigg(String text) => text;
}

import 'package:flutter/material.dart';

/// The icon used for the kind of name a gazetteer entry is.
IconData mapNameIcon(String type) => switch (type) {
  'person' || 'deity' => Icons.person_outline,
  'animal' => Icons.pets_outlined,
  'group' => Icons.groups_outlined,
  _ => Icons.place_outlined,
};

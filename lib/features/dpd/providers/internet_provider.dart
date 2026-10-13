import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final hasInternetProvider = FutureProvider<bool>((ref) async {
  try {
    final result = await InternetAddress.lookup('dpdict.net')
        .timeout(const Duration(seconds: 5));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
});

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_release_service.dart';

/// When GitHub last answered a DPD release check, in ms since the epoch.
const kDpdLastCheckKey = 'dpd_update_last_check';

/// DPD releases come every month or two, so once a day is plenty, and far
/// under GitHub's 60 anonymous requests an hour.
const kDpdCheckInterval = Duration(hours: 24);

class DpdUpdateState {
  const DpdUpdateState({
    this.lastCheck,
    this.checking = false,
    this.latest,
    this.error,
  });

  /// The last time GitHub answered. Null before the first answer.
  final DateTime? lastCheck;
  final bool checking;

  /// The newest release from the last answer, newer or not.
  final DpdRelease? latest;

  /// Why the last "Check now" failed.
  final String? error;
}

/// The daily check at launch and "Check now" in settings. Only an answer
/// from GitHub counts as a check: a failed call records nothing, so the next
/// launch tries again, and its error is never shown as "up to date".
class DpdUpdateNotifier extends StateNotifier<DpdUpdateState> {
  DpdUpdateNotifier({DpdReleaseService? service, DateTime Function()? now})
    : _service = service ?? DpdReleaseService(),
      _now = now ?? DateTime.now,
      super(const DpdUpdateState()) {
    _loaded = _loadLastCheck();
  }

  final DpdReleaseService _service;
  final DateTime Function() _now;
  late final Future<void> _loaded;

  /// Nobody may await this before the first check, so a failure is logged
  /// here; the check then runs as if it never had.
  Future<void> _loadLastCheck() async {
    final int? ms;
    try {
      final prefs = await SharedPreferences.getInstance();
      ms = prefs.getInt(kDpdLastCheckKey);
    } catch (e) {
      developer.log('DPD last check unreadable: $e', name: 'epitaka.dpd');
      return;
    }
    if (ms != null && mounted) {
      state = DpdUpdateState(
        lastCheck: DateTime.fromMillisecondsSinceEpoch(ms),
        latest: state.latest,
      );
    }
  }

  /// The launch check: asks GitHub only when the last answer is a day old,
  /// and returns the release to offer when it is newer than [installedTag].
  /// Throws when GitHub cannot be read.
  Future<DpdRelease?> checkIfDue(String? installedTag) async {
    await _loaded;
    final last = state.lastCheck;
    // A time in the future (the clock was set back) counts as due.
    final age = last == null ? null : _now().difference(last);
    if (age != null && !age.isNegative && age < kDpdCheckInterval) {
      return null;
    }
    final latest = await _fetch();
    return latest.isNewerThan(installedTag) ? latest : null;
  }

  /// "Check now": always asks. The result, or the error, lands in [state].
  Future<void> checkNow() async {
    await _loaded;
    state = DpdUpdateState(
      lastCheck: state.lastCheck,
      checking: true,
      latest: state.latest,
    );
    try {
      await _fetch();
    } catch (e) {
      // Any failure ends "checking" and is shown, so the button comes back.
      if (!mounted) return;
      state = DpdUpdateState(
        lastCheck: state.lastCheck,
        latest: state.latest,
        error: e is DpdReleaseException ? e.message : e.toString(),
      );
    }
  }

  Future<DpdRelease> _fetch() async {
    final latest = await _service.fetchLatest();
    final now = _now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kDpdLastCheckKey, now.millisecondsSinceEpoch);
    if (mounted) state = DpdUpdateState(lastCheck: now, latest: latest);
    return latest;
  }
}

final dpdUpdateProvider =
    StateNotifierProvider<DpdUpdateNotifier, DpdUpdateState>(
      (ref) => DpdUpdateNotifier(),
    );

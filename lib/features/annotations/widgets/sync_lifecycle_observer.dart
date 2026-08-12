// lib/features/annotations/widgets/sync_lifecycle_observer.dart
//
// Keeps the annotation sync service alive for the whole app run and, every
// time the app returns to the foreground, re-syncs with Supabase.
//
// Why this exists: Supabase Realtime only delivers changes over the live
// WebSocket. When the OS suspends the network in the background (or the app
// is killed), those events are lost. pullAndMerge() fetches the user's full
// annotation set and LWW-merges it locally, so edits made in the Supabase
// dashboard or on another device always show up shortly after the app is
// opened again.

import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/annotations_provider.dart';

class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Force the sync provider into existence right away (it also wires the
    // auth listener that pulls + subscribes on sign-in). Unawaited on
    // purpose: everything it does is background and offline-safe.
    ref
        .read(annotationSyncProvider.future)
        .then((sync) {
          // Catch up once at startup too, in case events were missed while the
          // app was closed and the session has already been restored.
          sync.pullAndMerge();
          sync.subscribeRealtime();
        })
        .catchError((Object e, StackTrace st) {
          developer.log(
            '[SYNC] startup sync failed: $e',
            name: 'epitaka.sync',
            error: e,
            stackTrace: st,
          );
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref
        .read(annotationSyncProvider.future)
        .then((sync) {
          // Full pull + LWW merge — the source of truth for anything realtime
          // missed while the app was suspended.
          sync.pullAndMerge();
          // No-op when the channel is already subscribed; realtime reconnects
          // its own socket, but re-asserting costs nothing.
          sync.subscribeRealtime();
        })
        .catchError((Object e, StackTrace st) {
          developer.log(
            '[SYNC] resume sync failed: $e',
            name: 'epitaka.sync',
            error: e,
            stackTrace: st,
          );
        });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

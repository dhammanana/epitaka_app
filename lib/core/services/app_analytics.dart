import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppAnalytics {
  AppAnalytics._();
  static final instance = AppAnalytics._();

  bool _ready = false;
  bool get isReady => _ready;

  bool _analyticsEnabled = true;
  bool _crashEnabled = true;

  FirebaseAnalytics? _analytics;
  FirebaseAnalytics? get analytics => _ready ? _analytics : null;

  Future<void> init({
    required bool analyticsEnabled,
    required bool crashEnabled,
  }) async {
    _analyticsEnabled = analyticsEnabled;
    _crashEnabled = crashEnabled;
    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      _ready = true;
      await _analytics?.setAnalyticsCollectionEnabled(_analyticsEnabled);
      final crash = FirebaseCrashlytics.instance;
      await crash.setCrashlyticsCollectionEnabled(_crashEnabled);
      developer.log('[ANALYTICS] Firebase ready', name: 'epitaka.analytics');
    } catch (e) {
      _ready = false;
      developer.log(
        '[ANALYTICS] Firebase unavailable (non-Android/no config): $e',
        name: 'epitaka.analytics',
      );
    }
  }

  Future<void> setCollectionEnabled({
    bool? analyticsEnabled,
    bool? crashEnabled,
  }) async {
    if (analyticsEnabled != null) _analyticsEnabled = analyticsEnabled;
    if (crashEnabled != null) _crashEnabled = crashEnabled;
    if (!_ready) return;
    try {
      await _analytics?.setAnalyticsCollectionEnabled(_analyticsEnabled);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        _crashEnabled,
      );
    } catch (_) {}
  }

  Future<void> logScreen(String name) async {
    if (!_ready || !_analyticsEnabled) return;
    try {
      await _analytics?.logScreenView(screenName: name);
    } catch (_) {}
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!_ready || !_analyticsEnabled) return;
    try {
      await _analytics?.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  Future<void> setUserId(String? id) async {
    if (!_ready) return;
    try {
      await _analytics?.setUserId(id: id);
      await FirebaseCrashlytics.instance.setUserIdentifier(id ?? '');
    } catch (_) {}
  }

  Future<void> setCustomKeys(Map<String, String> keys) async {
    if (!_ready) return;
    try {
      for (final e in keys.entries) {
        await FirebaseCrashlytics.instance.setCustomKey(e.key, e.value);
      }
    } catch (_) {}
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_ready || !_crashEnabled) return;
    try {
      await FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (_) {}
  }

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_ready || !_crashEnabled) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {}
  }

  Future<void> log(String message) async {
    if (!_ready || !_crashEnabled) return;
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/features/desktop/window_state.dart';

const _channel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var maximized = false;
  var fullScreen = false;
  var minimized = false;
  final calls = <String>[];

  setUp(() {
    maximized = false;
    fullScreen = false;
    minimized = false;
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isMaximized':
          return maximized;
        case 'isFullScreen':
          return fullScreen;
        case 'isMinimized':
          return minimized;
        case 'getBounds':
          return {'x': 10.0, 'y': 20.0, 'width': 900.0, 'height': 700.0};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('decodeBounds', () {
    test('reads good bounds, including whole numbers', () {
      expect(decodeBounds('{"x": 10, "y": 20.5, "width": 900, "height": 700}'),
          const Rect.fromLTWH(10, 20.5, 900, 700));
      expect(decodeBounds(encodeBounds(const Rect.fromLTWH(1, 2, 800, 600))),
          const Rect.fromLTWH(1, 2, 800, 600));
    });

    test('gives null for missing, bad or too-small bounds', () {
      expect(decodeBounds(null), isNull);
      expect(decodeBounds('not json'), isNull);
      expect(decodeBounds('{"x": 1}'), isNull);
      expect(decodeBounds('{"x": 0, "y": 0, "width": 399, "height": 700}'),
          isNull);
      expect(decodeBounds('{"x": 0, "y": 0, "width": 900, "height": 299}'),
          isNull);
    });
  });

  group('restoreWindowState', () {
    test('sets bounds before maximizing, and never queries state', () async {
      SharedPreferences.setMockInitialValues({
        'window_state': 'maximized',
        'window_bounds': encodeBounds(const Rect.fromLTWH(1, 2, 800, 600)),
      });
      final prefs = await SharedPreferences.getInstance();

      await restoreWindowState(prefs);

      expect(calls, ['ensureInitialized', 'setBounds', 'maximize']);
    });

    test('full screen is restored as full screen', () async {
      SharedPreferences.setMockInitialValues({'window_state': 'fullscreen'});
      final prefs = await SharedPreferences.getInstance();

      await restoreWindowState(prefs);

      expect(calls, ['ensureInitialized', 'setFullScreen']);
    });
  });

  group('WindowStateSaver', () {
    late SharedPreferences prefs;
    late WindowStateSaver saver;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      saver = WindowStateSaver(prefs);
    });

    test('state events save the matching mode', () {
      saver.onWindowMaximize();
      expect(prefs.getString('window_state'), 'maximized');
      saver.onWindowEnterFullScreen();
      expect(prefs.getString('window_state'), 'fullscreen');
      saver.onWindowUnmaximize();
      expect(prefs.getString('window_state'), 'normal');
    });

    test('leaving full screen into a maximized window saves maximized',
        () async {
      maximized = true;
      saver.onWindowEnterFullScreen();

      saver.onWindowLeaveFullScreen();
      await pumpEventQueue();

      expect(prefs.getString('window_state'), 'maximized');
    });

    test('leaving full screen into a normal window saves normal', () async {
      saver.onWindowEnterFullScreen();

      saver.onWindowLeaveFullScreen();
      await pumpEventQueue();

      expect(prefs.getString('window_state'), 'normal');
    });

    test('a resize of a normal window saves its bounds after a pause',
        () async {
      saver.onWindowResize();
      expect(prefs.getString('window_bounds'), isNull);

      await Future<void>.delayed(const Duration(seconds: 1));

      expect(decodeBounds(prefs.getString('window_bounds')),
          const Rect.fromLTWH(10, 20, 900, 700));
    });

    test('a resize while maximized leaves the saved bounds alone', () async {
      maximized = true;
      saver.onWindowResize();
      await Future<void>.delayed(const Duration(seconds: 1));

      expect(prefs.getString('window_bounds'), isNull);
    });

    test('a move while full screen leaves the saved bounds alone', () async {
      fullScreen = true;
      saver.onWindowMove();
      await Future<void>.delayed(const Duration(seconds: 1));

      expect(prefs.getString('window_bounds'), isNull);
    });
  });
}

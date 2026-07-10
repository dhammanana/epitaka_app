/// Widget tests for the AI Assistant (Paññā) feature.
///
/// Tests cover:
///   - [AiChatMessageBubble]: user/assistant rendering, mode badges,
///     streaming text, [Source N] links, sources bar.
///   - [AiAssistantScreen]: empty state, mode selector, error banner,
///     message list, settings button, input bar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka_app/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:epitaka_app/features/ai_assistant/widgets/ai_chat_message_bubble.dart';
import 'package:epitaka_app/features/ai_assistant/screens/ai_assistant_screen.dart';
import 'package:epitaka_app/features/ai_assistant/providers/ai_chat_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Fake Notifier for controlled state in tests
// ═══════════════════════════════════════════════════════════════════════

class FakeAiChatNotifier extends AiChatNotifier {
  FakeAiChatNotifier(super.ref);

  void setState(AiChatState newState) {
    state = newState;
  }

  @override
  Future<void> sendMessage(String text) async {}

  @override
  void clearChat() {
    state = const AiChatState();
  }
}

FakeAiChatNotifier? _testNotifier;

FakeAiChatNotifier get testAiChatNotifier {
assert(_testNotifier != null,
    'Must call _pumpScreen or _pumpBubble before accessing testAiChatNotifier');
  return _testNotifier!;
}

// ═══════════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════════

/// Core wrapper: ProviderScope (overriding aiChatProvider) + MaterialApp.
Widget _buildProviders(Widget child) {
  return ProviderScope(
    overrides: [
      aiChatProvider.overrideWith((ref) {
        final notifier = FakeAiChatNotifier(ref);
        _testNotifier = notifier;
        return notifier;
      }),
    ],
    child: MaterialApp(home: child),
  );
}

/// Pump an [AiChatMessageBubble] wrapped in a Scaffold so that ActionChip
/// widgets have the required Material ancestor.
Future<void> _pumpBubble(WidgetTester tester, {
  required AiChatMessage message,
  String? streamingText,
}) async {
  await tester.pumpWidget(
    _buildProviders(Scaffold(
      body: AiChatMessageBubble(
        message: message,
        streamingText: streamingText,
      ),
    )),
  );
}

/// Pump the [AiAssistantScreen] with an optional [initialState].
/// Sets a larger viewport (400×800) to prevent layout overflow errors.
Future<void> _pumpScreen(WidgetTester tester, {
  AiChatState? initialState,
}) async {
  // Use a tablet-proportioned viewport so the dense empty state content
  // (icon, title, description, warning banner, buttons) fits without
  // overflowing. 1080×1920 @ 2.0 DPR = logical 540×960.
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    _buildProviders(const AiAssistantScreen()),
  );

  // Apply initial state after first build if provided
  if (initialState != null && _testNotifier != null) {
    _testNotifier!.setState(initialState);
    await tester.pump();
  }
}

AiChatMessage _userMsg(
  String text, {
  AiChatMode mode = AiChatMode.answerQuestion,
}) {
  return AiChatMessage(
    id: 'user-1',
    text: text,
    isUser: true,
    timestamp: DateTime(2025, 1, 1, 12, 0),
    mode: mode,
  );
}

AiChatMessage _assistantMsg(
  String text, {
  AiChatMode mode = AiChatMode.answerQuestion,
  List<SourceReference> sources = const [],
}) {
  return AiChatMessage(
    id: 'asst-1',
    text: text,
    isUser: false,
    timestamp: DateTime(2025, 1, 1, 12, 1),
    mode: mode,
    sources: sources,
  );
}

SourceReference _source({
  String bookId = 'dn1',
  int paraId = 1,
  int lineId = 1,
  String? bookName,
}) {
  return SourceReference(
    bookId: bookId,
    paraId: paraId,
    lineId: lineId,
    excerpt: 'Test excerpt text for the source reference.',
    bookName: bookName,
  );
}

// ═══════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _testNotifier = null;
  });

  // ─────────────────────────────────────────────────────────────────────
  //  AiChatMessageBubble
  // ─────────────────────────────────────────────────────────────────────

  group('AiChatMessageBubble', () {
    testWidgets('renders user message text', (tester) async {
      await _pumpBubble(tester, message: _userMsg('What is anatta?'));

      expect(find.text('What is anatta?'), findsOneWidget);
    });

    testWidgets('renders assistant message text with badge', (tester) async {
      await _pumpBubble(
        tester,
        message: _assistantMsg('Anatta means not-self.'),
      );

      expect(find.text('Anatta means not-self.'), findsOneWidget);
      expect(find.textContaining('Answer'), findsOneWidget);
    });

    testWidgets('shows Literal Review badge in literal review mode',
        (tester) async {
      await _pumpBubble(
        tester,
        message: _assistantMsg(
          'Research on anatta.',
          mode: AiChatMode.literalReview,
        ),
      );

      expect(find.textContaining('Literal Review'), findsOneWidget);
    });

    testWidgets('shows streaming text when isStreaming is true',
        (tester) async {
      final streamingMsg = AiChatMessage(
        id: 'stream-1',
        text: '',
        isUser: false,
        timestamp: DateTime(2025, 1, 1, 12, 1),
        mode: AiChatMode.answerQuestion,
        isStreaming: true,
      );

      await _pumpBubble(
        tester,
        message: streamingMsg,
        streamingText: 'Partial answer streaming\u2026',
      );

      expect(find.text('Partial answer streaming\u2026'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator during streaming',
        (tester) async {
      final streamingMsg = AiChatMessage(
        id: 'stream-2',
        text: '',
        isUser: false,
        timestamp: DateTime(2025, 1, 1, 12, 1),
        mode: AiChatMode.answerQuestion,
        isStreaming: true,
      );

      await _pumpBubble(tester, message: streamingMsg, streamingText: 'Token');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides CircularProgressIndicator when not streaming',
        (tester) async {
      await _pumpBubble(tester, message: _assistantMsg('Done.'));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders [Source N] inline links', (tester) async {
      final msg = _assistantMsg(
        'According to the Canon [Source 1], anatta is central.',
        sources: [_source()],
      );

      await _pumpBubble(tester, message: msg);

      expect(find.text('[Source 1]'), findsOneWidget);
    });

    testWidgets('renders multiple [Source N] links', (tester) async {
      final msg = _assistantMsg(
        '[Source 1] says this, but [Source 2] says that.',
        sources: [_source(), _source(bookId: 'mn1', paraId: 2)],
      );

      await _pumpBubble(tester, message: msg);

      expect(find.text('[Source 1]'), findsOneWidget);
      expect(find.text('[Source 2]'), findsOneWidget);
    });

    testWidgets('renders SelectableText.rich for assistant content',
        (tester) async {
      final msg = _assistantMsg(
        'Start [Source 1] end.',
        sources: [_source()],
      );

      await _pumpBubble(tester, message: msg);

      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('[Source 1]'), findsOneWidget);
    });

    testWidgets('shows sources bar header when sources present',
        (tester) async {
      final msg = _assistantMsg(
        'Answer with source.',
        sources: [_source(bookName: 'DN 1')],
      );

      await _pumpBubble(tester, message: msg);

      expect(find.text('Sources (1)'), findsOneWidget);
    });

    testWidgets('hides sources bar when sources are empty', (tester) async {
      await _pumpBubble(tester, message: _assistantMsg('No sources.'));

      expect(find.text('Sources (0)'), findsNothing);
    });

    testWidgets('contains Padding widgets for message layout', (tester) async {
      await _pumpBubble(tester, message: _userMsg('Hello'));

      expect(find.byType(Padding), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  //  AiAssistantScreen
  // ─────────────────────────────────────────────────────────────────────

  group('AiAssistantScreen', () {
    testWidgets('shows title bar with feature name', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Paññā'), findsWidgets);
      expect(find.text('AI Research Assistant'), findsOneWidget);
    });

    testWidgets('shows mode selector with Q&A and Literal Review',
        (tester) async {
      await _pumpScreen(tester);

      expect(find.textContaining('Answer'), findsOneWidget);
      expect(find.textContaining('Literal Review'), findsOneWidget);
    });

    testWidgets('shows empty state for default answer mode', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Ask a Question'), findsOneWidget);
    });

    testWidgets('shows input bar with Q&A hint text', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.text('Ask a question about the Tipitaka\u2026'),
        findsOneWidget,
      );
    });

    testWidgets('switches hint text when mode changes', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.text('Ask a question about the Tipitaka\u2026'),
        findsOneWidget,
      );

      // Tap Literal Review mode option (label has 📖 emoji prefix)
      await tester.tap(find.textContaining('Literal Review'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a research topic\u2026'),
        findsOneWidget,
      );
    });

    testWidgets('shows API key required warning when settings empty',
        (tester) async {
      await _pumpScreen(tester);

      expect(find.text('API key required'), findsWidgets);
      expect(find.text('Configure API Key'), findsOneWidget);
    });

    testWidgets('shows settings gear icon button', (tester) async {
      await _pumpScreen(tester);

      expect(find.byTooltip('AI Settings'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsAtLeast(1));
    });

    testWidgets('shows and dismisses error banner', (tester) async {
      await _pumpScreen(
        tester,
        initialState: const AiChatState(error: 'A test error occurred.'),
      );

      expect(find.text('A test error occurred.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('A test error occurred.'), findsNothing);
    });

    testWidgets('shows error at runtime via setState', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('Runtime error'), findsNothing);

      testAiChatNotifier.setState(
        const AiChatState(error: 'Runtime error'),
      );
      await tester.pump();

      expect(find.text('Runtime error'), findsOneWidget);
    });

    testWidgets('renders messages in the message list', (tester) async {
      await _pumpScreen(
        tester,
        initialState: AiChatState(
          messages: [
            _userMsg('What is anicca?'),
            _assistantMsg('Anicca means impermanence.'),
          ],
        ),
      );

      expect(find.text('What is anicca?'), findsOneWidget);
      expect(find.text('Anicca means impermanence.'), findsOneWidget);
    });

    testWidgets('hides empty state when messages are present', (tester) async {
      await _pumpScreen(
        tester,
        initialState: AiChatState(
          messages: [_userMsg('Q'), _assistantMsg('A')],
        ),
      );

      expect(find.text('Ask a Question'), findsNothing);
      expect(find.text('Q'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('send button shows arrow icon when idle', (tester) async {
      await _pumpScreen(tester);

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('send button shows spinner during loading', (tester) async {
      await _pumpScreen(
        tester,
        initialState: const AiChatState(isLoading: true),
      );

      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsAtLeast(1));
    });

    testWidgets('send button is disabled during streaming', (tester) async {
      await _pumpScreen(
        tester,
        initialState: const AiChatState(isStreaming: true),
      );

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.onSubmitted, isNull);
    });

    testWidgets('typing in input bar works', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'What is kamma?');
      await tester.pump();

      expect(find.text('What is kamma?'), findsOneWidget);
    });

    testWidgets('renders Scaffold without crashing', (tester) async {
      await _pumpScreen(tester);

      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

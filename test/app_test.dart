import 'package:cowbullgame/app.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [WordRepository] fake so app-level navigation can be exercised
/// without touching the real bundled word-list assets.
class _FakeWordRepository implements WordRepository {
  final Map<int, String> wordsByLength = {};

  @override
  Future<String> selectSecretWord(int wordLength) async {
    final word = wordsByLength[wordLength];
    if (word == null) {
      throw StateError('no fake secret word registered for length $wordLength');
    }
    return word;
  }

  @override
  Future<List<String>> loadAllowedWords(int wordLength) async => const [];

  @override
  Future<List<String>> loadSecretWords(int wordLength) async => const [];

  @override
  Future<bool> isAllowed(String word, int wordLength) async => true;
}

void main() {
  testWidgets('the app starts on the home screen', (tester) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('4, 5, and 6 letter options are visible on launch', (
    tester,
  ) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    expect(find.text('4 letters'), findsOneWidget);
    expect(find.text('5 letters'), findsOneWidget);
    expect(find.text('6 letters'), findsOneWidget);
  });

  testWidgets('selecting an option updates the visible selection', (
    tester,
  ) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('6 letters'));
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(segmentedButton.selected, {6});
  });

  testWidgets('starting a game navigates to the gameplay screen', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsNothing);
    expect(find.text('Bulls & Cows · 4 letters'), findsOneWidget);
  });

  testWidgets('starting a game uses the correct GameConfig for the '
      'selected word length', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[6] = 'garden';
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('6 letters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.text('Bulls & Cows · 6 letters'), findsOneWidget);
    // Attempts limit for 6-letter games (GameConfig.forWordLength(6)).
    expect(find.textContaining('20'), findsWidgets);
  });
}

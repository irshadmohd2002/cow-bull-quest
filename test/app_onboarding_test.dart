import 'package:cowbullgame/app.dart';
import 'package:cowbullgame/coin_wallet.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/features/onboarding/controllers/onboarding_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [WordRepository] fake — mirrors `app_test.dart`'s own, kept
/// separate since that one is file-private.
class _FakeWordRepository implements WordRepository {
  final Map<int, String> wordsByLength = {};

  @override
  Future<String> selectSecretWord(
    int wordLength,
    GameDifficulty difficulty,
  ) async {
    final word = wordsByLength[wordLength];
    if (word == null) {
      throw StateError('no fake secret word registered for length $wordLength');
    }
    return word;
  }

  @override
  Future<List<String>> loadAllowedWords(int wordLength) async => const [];

  @override
  Future<List<String>> loadSecretWords(
    int wordLength,
    GameDifficulty difficulty,
  ) async => const [];

  @override
  Future<bool> isAllowed(String word, int wordLength) async => true;
}

void main() {
  testWidgets('by default (no onboarding controller injected) the app '
      'opens directly on Home — the fallback starts already completed', (
    tester,
  ) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsOneWidget);
    expect(find.text('Guess the Secret Word'), findsNothing);
  });

  group('first-launch onboarding', () {
    testWidgets('shows onboarding instead of Home when not yet completed', (
      tester,
    ) async {
      final onboarding = OnboardingController(initialCompleted: false);
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          onboardingController: onboarding,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guess the Secret Word'), findsOneWidget);
      expect(find.text('Start Game'), findsNothing);
    });

    testWidgets('skipping onboarding shows Home, with nothing left beneath '
        'it to pop back to', (tester) async {
      final onboarding = OnboardingController(initialCompleted: false);
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          onboardingController: onboarding,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Start Game'), findsOneWidget);
      expect(onboarding.completed, isTrue);
    });

    testWidgets('finishing onboarding through every page shows Home', (
      tester,
    ) async {
      final onboarding = OnboardingController(initialCompleted: false);
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          onboardingController: onboarding,
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Start Game'), findsOneWidget);
      expect(onboarding.completed, isTrue);
    });

    testWidgets('app restart after completion opens Home directly', (
      tester,
    ) async {
      // Simulates "restart": a fresh CowBullApp built from an
      // already-completed controller, exactly what AppBootstrap.load would
      // produce on the next launch after onboarding was finished.
      final onboarding = OnboardingController(initialCompleted: true);
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          onboardingController: onboarding,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Game'), findsOneWidget);
    });
  });

  group('manual "View Tutorial" replay', () {
    testWidgets('is reachable from Settings after onboarding is already '
        'completed', (tester) async {
      final onboarding = OnboardingController(initialCompleted: true);
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          onboardingController: onboarding,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Tutorial'));
      await tester.tap(find.text('View Tutorial'));
      await tester.pumpAndSettle();

      expect(find.text('Guess the Secret Word'), findsOneWidget);
    });

    testWidgets('closing a manually-opened tutorial returns to Settings, '
        'the screen that opened it', (tester) async {
      final onboarding = OnboardingController(initialCompleted: true);
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          onboardingController: onboarding,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Tutorial'));
      await tester.tap(find.text('View Tutorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Follow system'), findsOneWidget); // back on Settings
    });

    testWidgets('is reachable from the Rules ("How to Play") screen too', (
      tester,
    ) async {
      final onboarding = OnboardingController(initialCompleted: true);
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          onboardingController: onboarding,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('How to Play'));
      await tester.tap(find.text('How to Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tutorial'));
      await tester.pumpAndSettle();

      expect(find.text('Guess the Secret Word'), findsOneWidget);
    });

    testWidgets('manually viewing and closing the tutorial never changes '
        'coins, or leaves onboarding in a different state', (tester) async {
      final onboarding = OnboardingController(initialCompleted: true);
      final coinWallet = CoinWallet();
      addTearDown(coinWallet.dispose);
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          onboardingController: onboarding,
          coinWallet: coinWallet,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Tutorial'));
      await tester.tap(find.text('View Tutorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
      expect(onboarding.completed, isTrue);
    });
  });
}

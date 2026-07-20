import 'package:cowbullgame/app.dart';
import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/coin_wallet.dart';
import 'package:cowbullgame/core/privacy_policy.dart' as privacy_policy_config;
import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/game/data/asset_word_repository.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/widgets/share_cards/daily_challenge_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_local_date_provider.dart';
import 'support/fake_preferences_store.dart';
import 'support/fake_share_card_renderer.dart';
import 'support/fake_share_card_service.dart';
import 'support/fake_statistics_repository.dart';

/// A minimal [WordRepository] fake so app-level navigation can be exercised
/// without touching the real bundled word-list assets. [wordsByLength] is
/// keyed by word length only, since these app-navigation tests don't need
/// to distinguish difficulty pools — cross-difficulty behavior is covered
/// by `asset_word_repository_test.dart` and `game_controller_test.dart`.
class _FakeWordRepository implements WordRepository {
  final Map<int, String> wordsByLength = {};
  final List<int> requestedLengths = [];
  final List<GameDifficulty> requestedDifficulties = [];

  /// Words [loadAllowedWords] returns, keyed by word length. Seeded with
  /// every real guess literal this file submits through the UI (only
  /// `lace`), so tests don't need to register anything themselves.
  final Map<int, Set<String>> allowedWordsByLength = {
    4: {'lace'},
  };

  /// The ordered eligible-word pool [loadSecretWords] returns, keyed by
  /// `(wordLength, difficulty)` — only used by Daily Challenge tests, which
  /// compute the deterministic secret word from this pool via
  /// `DailyChallengeService.secretWordFor`. Empty (no candidates) unless a
  /// test populates it.
  final Map<(int, GameDifficulty), List<String>>
  secretWordsByLengthAndDifficulty = {};

  @override
  Future<String> selectSecretWord(
    int wordLength,
    GameDifficulty difficulty,
  ) async {
    requestedLengths.add(wordLength);
    requestedDifficulties.add(difficulty);
    final word = wordsByLength[wordLength];
    if (word == null) {
      throw StateError('no fake secret word registered for length $wordLength');
    }
    return word;
  }

  @override
  Future<List<String>> loadAllowedWords(int wordLength) async =>
      List.unmodifiable(allowedWordsByLength[wordLength] ?? const <String>{});

  @override
  Future<List<String>> loadSecretWords(
    int wordLength,
    GameDifficulty difficulty,
  ) async => List.unmodifiable(
    secretWordsByLengthAndDifficulty[(wordLength, difficulty)] ?? const [],
  );

  @override
  Future<bool> isAllowed(String word, int wordLength) async => true;
}

/// Drives a full, realistic background/resume cycle through every
/// intermediate [AppLifecycleState] Android/iOS actually pass through
/// (`resumed -> inactive -> hidden -> paused`, then back
/// `paused -> hidden -> inactive -> resumed`). Jumping straight from
/// `paused` to `resumed` violates Flutter's own lifecycle state machine
/// (asserted in `AppLifecycleListener`, which `EditableText`'s focus
/// handling attaches internally) and would fail with an assertion error on
/// any screen containing a text field.
Future<void> _backgroundAndResume(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

/// Pumps enough frames for the share-card preview sheet to finish opening
/// and its (fake, near-instant) render to complete.
///
/// Deliberately not `pumpAndSettle`: the completed screen's own Share Win/
/// Challenge button shows an indeterminate spinner for as long as the
/// preview sheet stays open, which `pumpAndSettle` can never treat as
/// "settled".
Future<void> pumpForPreviewToOpen(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('CowBullApp word repository composition', () {
    test('defaults to AssetWordRepository — the release build source of both '
        'secret words and the allowed-guess dictionary — when none is '
        'injected', () {
      final app = CowBullApp();
      expect(app.wordRepository, isA<AssetWordRepository>());
    });
  });

  testWidgets('the app starts on the home screen', (tester) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('no word-length selector is visible on launch', (tester) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.text('4 letters'), findsNothing);
    expect(find.text('5 letters'), findsNothing);
    expect(find.text('6 letters'), findsNothing);
  });

  testWidgets('starting a game navigates to the gameplay screen', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsNothing);
    expect(find.text('Cow Bull Quest'), findsOneWidget);
    expect(find.bySemanticsLabel('Guess input, 4 letters'), findsOneWidget);
  });

  testWidgets('starting a game always uses a 4-letter GameConfig with 10 '
      'attempts, regardless of difficulty', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Guess input, 4 letters'), findsOneWidget);
    // Attempts limit for 4-letter games (GameConfig.forSelection).
    expect(find.textContaining('10'), findsWidgets);
  });

  testWidgets('starting a game uses the correct GameConfig for the '
      'selected difficulty', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(repo.requestedDifficulties, [GameDifficulty.hard]);
  });

  testWidgets('the game screen displays the selected difficulty', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    // The status panel's difficulty chip renders as rich text.
    expect(
      find.textContaining('Easy', findRichText: true),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('How to Play opens the Rules screen', (tester) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('How to Play'));
    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();

    expect(find.text('How to Play'), findsWidgets);
    expect(find.text('Bulls'), findsWidgets);
  });

  testWidgets('Settings opens the Settings screen', (tester) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('back from Rules returns to Home', (tester) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('How to Play'));
    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('back from Settings returns to Home', (tester) async {
    await tester.pumpWidget(CowBullApp(wordRepository: _FakeWordRepository()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('selecting dark mode changes the MaterialApp theme', (
    tester,
  ) async {
    final settings = AppSettings();
    await tester.pumpWidget(
      CowBullApp(wordRepository: _FakeWordRepository(), settings: settings),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('theme remains dark after returning home', (tester) async {
    final settings = AppSettings();
    await tester.pumpWidget(
      CowBullApp(wordRepository: _FakeWordRepository(), settings: settings),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('starting a game after changing theme still works', (
    tester,
  ) async {
    final settings = AppSettings();
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    await tester.pumpWidget(
      CowBullApp(wordRepository: repo, settings: settings),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Guess input, 4 letters'), findsOneWidget);
  });

  testWidgets('opening Rules does not construct a GameController', (
    tester,
  ) async {
    final repo = _FakeWordRepository();
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('How to Play'));
    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();

    expect(repo.requestedLengths, isEmpty);
  });

  testWidgets('opening Settings does not construct a GameController', (
    tester,
  ) async {
    final repo = _FakeWordRepository();
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(repo.requestedLengths, isEmpty);
  });

  group('CowBullApp settings ownership', () {
    testWidgets(
      'the internally-created settings fallback is in-memory only — it '
      'attempts no real persistence, unlike the main.dart/AppBootstrap path',
      (tester) async {
        // This test configures no SharedPreferences mock at all. If the
        // fallback AppSettings created when `settings:` is omitted ever
        // attempted real persistence, selecting Dark below would surface a
        // MissingPluginException instead of just updating the UI — so this
        // test passing is itself proof the fallback is non-persistent, as
        // documented on CowBullApp.settings.
        await tester.pumpWidget(
          CowBullApp(wordRepository: _FakeWordRepository()),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.themeMode, ThemeMode.dark);
      },
    );

    testWidgets(
      'an internally-created settings controller functions correctly and '
      'is disposed cleanly when CowBullApp is removed',
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(wordRepository: _FakeWordRepository()),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();

        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.themeMode, ThemeMode.dark);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        // No assertion failure means dispose() completed exactly once,
        // cleanly, for the internally-created instance.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a fresh CowBullApp still works normally after a previous '
        'internally-owned instance was disposed', (tester) async {
      await tester.pumpWidget(
        CowBullApp(wordRepository: _FakeWordRepository()),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        CowBullApp(wordRepository: _FakeWordRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Game'), findsOneWidget);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
    });

    testWidgets(
      'an injected AppSettings is not disposed by CowBullApp — the caller '
      'can still dispose it exactly once',
      (tester) async {
        final settings = AppSettings();
        await tester.pumpWidget(
          CowBullApp(wordRepository: _FakeWordRepository(), settings: settings),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        // If CowBullApp had already disposed this instance, disposing it
        // again here would trigger a "used after being disposed" assertion
        // failure — so this passing proves CowBullApp never disposed it.
        expect(settings.dispose, returnsNormally);
      },
    );

    testWidgets(
      'an injected AppSettings remains usable after CowBullApp is removed '
      'from the tree',
      (tester) async {
        final settings = AppSettings();
        await tester.pumpWidget(
          CowBullApp(wordRepository: _FakeWordRepository(), settings: settings),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        expect(
          () => settings.setThemePreference(AppThemePreference.dark),
          returnsNormally,
        );
        expect(settings.themePreference, AppThemePreference.dark);
      },
    );

    testWidgets('theme updates through an injected AppSettings still rebuild '
        'MaterialApp', (tester) async {
      final settings = AppSettings();
      await tester.pumpWidget(
        CowBullApp(wordRepository: _FakeWordRepository(), settings: settings),
      );
      await tester.pumpAndSettle();

      settings.setThemePreference(AppThemePreference.dark);
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });

  group('CowBullApp Statistics navigation', () {
    testWidgets('Statistics opens from Home and starts empty', (tester) async {
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          statisticsRepository: FakeStatisticsRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Statistics'));
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No completed games yet'), findsOneWidget);
    });

    testWidgets('back from Statistics returns to Home', (tester) async {
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          statisticsRepository: FakeStatisticsRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Statistics'));
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Start Game'), findsOneWidget);
    });

    testWidgets('opening Statistics does not construct a GameController', (
      tester,
    ) async {
      final repo = _FakeWordRepository();
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: repo,
          statisticsRepository: FakeStatisticsRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Statistics'));
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      expect(repo.requestedLengths, isEmpty);
    });

    testWidgets('theme persists while navigating to Statistics', (
      tester,
    ) async {
      final settings = AppSettings();
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          settings: settings,
          statisticsRepository: FakeStatisticsRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Statistics'));
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });

  group('CowBullApp completed-game recording', () {
    Future<void> enterAndSubmit(WidgetTester tester, String guess) async {
      await tester.enterText(find.byType(TextField), guess);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
    }

    testWidgets('a won game is recorded exactly once into statistics', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final statisticsRepository = FakeStatisticsRepository();
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: repo,
          statisticsRepository: statisticsRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      await enterAndSubmit(tester, 'lace');
      expect(find.text('You won!'), findsOneWidget);

      expect(statisticsRepository.recordedGames, hasLength(1));
      expect(statisticsRepository.recordedGames.single.wordLength, 4);
    });

    testWidgets('completing a game updates the Statistics screen', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final statisticsRepository = FakeStatisticsRepository();
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: repo,
          statisticsRepository: statisticsRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Statistics'));
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No completed games yet'), findsNothing);
      expect(find.textContaining('Won'), findsOneWidget);
    });

    testWidgets(
      'restarting a completed game allows a second distinct recording',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final statisticsRepository = FakeStatisticsRepository();
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: repo,
            statisticsRepository: statisticsRepository,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');
        expect(statisticsRepository.recordedGames, hasLength(1));

        await tester.tap(find.text('Play Again'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(statisticsRepository.recordedGames, hasLength(2));
        expect(
          statisticsRepository.recordedGames[0].id,
          isNot(statisticsRepository.recordedGames[1].id),
        );
      },
    );

    testWidgets('navigating away after completion does not record again', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final statisticsRepository = FakeStatisticsRepository();
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: repo,
          statisticsRepository: statisticsRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');
      expect(statisticsRepository.recordedGames, hasLength(1));

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(statisticsRepository.recordedGames, hasLength(1));
    });

    testWidgets('an abandoned in-progress game is never recorded', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final statisticsRepository = FakeStatisticsRepository();
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: repo,
          statisticsRepository: statisticsRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(statisticsRepository.recordedGames, isEmpty);
    });

    testWidgets('a failed startup is never recorded', (tester) async {
      final repo = _FakeWordRepository();
      final statisticsRepository = FakeStatisticsRepository();
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: repo,
          statisticsRepository: statisticsRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't start the game. Please try again."),
        findsOneWidget,
      );
      expect(statisticsRepository.recordedGames, isEmpty);
    });

    testWidgets('a statistics write failure does not block the completion UI', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final statisticsRepository = FakeStatisticsRepository()
        ..failRecord = true;
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: repo,
          statisticsRepository: statisticsRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.text('You won!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CowBullApp rapid-tap navigation guard', () {
    testWidgets(
      'a rapid double-tap on Start Game produces at most one Game route',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        await tester.pumpWidget(CowBullApp(wordRepository: repo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        // The second tap fires before either has been pumped — exactly the
        // rapid-double-tap scenario this guard protects against. By the
        // time it's dispatched the first tap may have already started
        // covering Home with the new route, so a stray hit-test miss here
        // is expected and harmless.
        await tester.tap(find.text('Start Game'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Guess input, 4 letters'), findsOneWidget);

        // A single pop reaches Home — if two routes had stacked, one pop
        // would still leave a second Game screen showing.
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Start Game'), findsOneWidget);
      },
    );

    testWidgets(
      'a rapid double-tap on How to Play produces at most one Rules route',
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(wordRepository: _FakeWordRepository()),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('How to Play'));
        await tester.tap(find.text('How to Play'));
        await tester.tap(find.text('How to Play'), warnIfMissed: false);
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Start Game'), findsOneWidget);
      },
    );

    testWidgets(
      'a rapid double-tap on Settings produces at most one Settings route',
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(wordRepository: _FakeWordRepository()),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.tap(find.text('Settings'), warnIfMissed: false);
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Start Game'), findsOneWidget);
      },
    );

    testWidgets(
      'a rapid double-tap on Statistics produces at most one Statistics '
      'route',
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: _FakeWordRepository(),
            statisticsRepository: FakeStatisticsRepository(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Statistics'));
        await tester.tap(find.text('Statistics'));
        await tester.tap(find.text('Statistics'), warnIfMissed: false);
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Start Game'), findsOneWidget);
      },
    );

    testWidgets('sequential navigation is unaffected by the guard — Rules then '
        'Settings both open normally', (tester) async {
      await tester.pumpWidget(
        CowBullApp(wordRepository: _FakeWordRepository()),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('How to Play'));
      await tester.tap(find.text('How to Play'));
      await tester.pumpAndSettle();
      expect(find.text('Bulls'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Follow system'), findsOneWidget);
    });
  });

  group('CowBullApp lifecycle safety', () {
    testWidgets('Home survives a background/resume cycle', (tester) async {
      await tester.pumpWidget(
        CowBullApp(wordRepository: _FakeWordRepository()),
      );
      await tester.pumpAndSettle();

      await _backgroundAndResume(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Start Game'), findsOneWidget);
      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cow Bull Quest'), findsOneWidget);
    });

    testWidgets('an active game survives a background/resume cycle and '
        'remains usable', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      await tester.pumpWidget(CowBullApp(wordRepository: repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      await _backgroundAndResume(tester);

      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'lace');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsOneWidget);
    });

    testWidgets('a completed game survives a background/resume cycle', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      await tester.pumpWidget(CowBullApp(wordRepository: repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'lace');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsOneWidget);

      await _backgroundAndResume(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('You won!'), findsOneWidget);
      await tester.tap(find.text('Play Again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cow Bull Quest'), findsOneWidget);
    });

    testWidgets('Statistics survives a background/resume cycle', (
      tester,
    ) async {
      final statisticsRepository = FakeStatisticsRepository();
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          statisticsRepository: statisticsRepository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Statistics'));
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      await _backgroundAndResume(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('No completed games yet'), findsOneWidget);
    });
  });

  group('Privacy Policy composition', () {
    testWidgets(
      'Settings shows a disabled Privacy Policy row while the configured '
      'URL is still the placeholder',
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: _FakeWordRepository(),
            privacyPolicyUrl: privacy_policy_config.placeholderPrivacyPolicyUrl,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('Available before public release.'), findsOneWidget);
      },
    );

    testWidgets(
      'the default composition (no explicit privacyPolicyUrl) uses the '
      "app's final release-ready URL and enables the row",
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(wordRepository: _FakeWordRepository()),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(
          find.text('View how Cow Bull Quest handles local data.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the default composition passes the centrally configured '
        'privacyPolicyUrl through — tapping launches exactly that URL', (
      tester,
    ) async {
      var callCount = 0;
      Uri? launchedUri;
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          urlLauncher: (uri) async {
            callCount++;
            launchedUri = uri;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(launchedUri, Uri.parse(privacy_policy_config.privacyPolicyUrl));
    });

    testWidgets('a non-HTTPS configured URL also keeps the row disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: _FakeWordRepository(),
          privacyPolicyUrl: 'http://cowbullquest.example/privacy',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Available before public release.'), findsOneWidget);
    });

    testWidgets(
      'a release-ready URL enables the row and tapping it invokes the '
      'injected launcher exactly once with that URL',
      (tester) async {
        var callCount = 0;
        Uri? launchedUri;
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: _FakeWordRepository(),
            privacyPolicyUrl: 'https://cowbullquest.example/privacy',
            urlLauncher: (uri) async {
              callCount++;
              launchedUri = uri;
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(
          find.text('View how Cow Bull Quest handles local data.'),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Privacy Policy'));
        await tester.tap(find.text('Privacy Policy'));
        await tester.pumpAndSettle();

        expect(callCount, 1);
        expect(launchedUri, Uri.parse('https://cowbullquest.example/privacy'));
      },
    );

    testWidgets(
      'shows a friendly message, never a raw error, when the launcher '
      'reports failure',
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: _FakeWordRepository(),
            privacyPolicyUrl: 'https://cowbullquest.example/privacy',
            urlLauncher: (uri) async => false,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Privacy Policy'));
        await tester.tap(find.text('Privacy Policy'));
        // Deliberately not pumpAndSettle: the shown SnackBar auto-dismisses
        // on its own timer, and pumpAndSettle would pump straight through
        // that entire lifecycle. A couple of bounded pumps is enough to let
        // the async launch attempt finish and the SnackBar's entrance
        // animation complete, while it's still on screen to assert against.
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        expect(tester.takeException(), isNull);
        expect(
          find.text(
            "Couldn't open the privacy policy. Please try again later.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows a friendly message, never a raw error, when the launcher '
      'throws',
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: _FakeWordRepository(),
            privacyPolicyUrl: 'https://cowbullquest.example/privacy',
            urlLauncher: (uri) async =>
                throw StateError('platform channel unavailable'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Privacy Policy'));
        await tester.tap(find.text('Privacy Policy'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        expect(tester.takeException(), isNull);
        expect(
          find.text(
            "Couldn't open the privacy policy. Please try again later.",
          ),
          findsOneWidget,
        );
        expect(find.textContaining('StateError'), findsNothing);
      },
    );
  });

  group('Milestone 14: coin wallet composition', () {
    testWidgets('Home shows the starting coin balance', (tester) async {
      await tester.pumpWidget(
        CowBullApp(wordRepository: _FakeWordRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('the Game screen shows the same coin balance as Home', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      await tester.pumpWidget(CowBullApp(wordRepository: repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('spending on a hint during a game is reflected on Home after '
        'returning', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      await tester.pumpWidget(CowBullApp(wordRepository: repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.lightbulb_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use 20 Coins'));
      await tester.pumpAndSettle();

      expect(find.text('80'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Start Game'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });

    testWidgets('changing the theme preference in Settings — a normal settings '
        'action, not a full data reset — never touches the coin balance', (
      tester,
    ) async {
      await tester.pumpWidget(
        CowBullApp(wordRepository: _FakeWordRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
    });
  });

  group('Milestone 18: streak and Daily Challenge', () {
    Future<void> enterAndSubmit(WidgetTester tester, String guess) async {
      await tester.enterText(find.byType(TextField), guess);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
    }

    LocalDate today() => LocalDate(year: 2026, month: 7, day: 18);

    testWidgets(
      'Home shows a friendly 0-day streak before any game is played',
      (tester) async {
        await tester.pumpWidget(
          CowBullApp(wordRepository: _FakeWordRepository()),
        );
        await tester.pumpAndSettle();

        expect(find.text('0-day streak'), findsOneWidget);
        expect(find.textContaining('Best: 0'), findsOneWidget);
      },
    );

    testWidgets('completing a normal game starts a 1-day streak, shown on the '
        'completed screen and back on Home', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      await tester.pumpWidget(
        CowBullApp(wordRepository: repo, clock: FakeLocalDateProvider(today())),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.textContaining('Streak started: 1 day'), findsOneWidget);

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('1-day streak'), findsOneWidget);
    });

    testWidgets(
      'a second completed game the same day does not extend the streak '
      'again',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: repo,
            clock: FakeLocalDateProvider(today()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');
        expect(find.textContaining('Streak started: 1 day'), findsOneWidget);

        await tester.tap(find.text('Play Again'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(
          find.textContaining('Today already counted · 1-day streak'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the Daily Challenge card is visible and shows "Not played"', (
      tester,
    ) async {
      await tester.pumpWidget(
        CowBullApp(wordRepository: _FakeWordRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Challenge'), findsOneWidget);
      expect(find.text('Not played'), findsOneWidget);
    });

    testWidgets(
      'starting the Daily Challenge uses 4 letters, Medium difficulty, and '
      '10 attempts',
      (tester) async {
        final repo = _FakeWordRepository()
          ..wordsByLength[4] = 'lace'
          ..secretWordsByLengthAndDifficulty[(4, GameDifficulty.common)] = [
            'lace',
          ];
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: repo,
            clock: FakeLocalDateProvider(today()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Daily Challenge'));
        await tester.tap(find.text('Daily Challenge'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Medium'), findsWidgets);
        expect(
          find.bySemanticsLabel(RegExp('Attempts used 0 of 10')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'winning the Daily Challenge marks Home "Completed · Won" and counts '
      "toward today's streak",
      (tester) async {
        final repo = _FakeWordRepository()
          ..wordsByLength[4] = 'lace'
          ..secretWordsByLengthAndDifficulty[(4, GameDifficulty.common)] = [
            'lace',
          ];
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: repo,
            clock: FakeLocalDateProvider(today()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Daily Challenge'));
        await tester.tap(find.text('Daily Challenge'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(find.text('You won!'), findsOneWidget);
        expect(find.textContaining('Streak started: 1 day'), findsOneWidget);

        await tester.ensureVisible(find.text('Home'));
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        expect(find.text('Completed · Won'), findsOneWidget);
        expect(find.text('1-day streak'), findsOneWidget);
      },
    );

    testWidgets(
      'a normal game and the Daily Challenge on the same day only count the '
      'streak once, however they are ordered',
      (tester) async {
        final repo = _FakeWordRepository()
          ..wordsByLength[4] = 'lace'
          ..secretWordsByLengthAndDifficulty[(4, GameDifficulty.common)] = [
            'lace',
          ];
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: repo,
            clock: FakeLocalDateProvider(today()),
          ),
        );
        await tester.pumpAndSettle();

        // Normal game first.
        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');
        expect(find.textContaining('Streak started: 1 day'), findsOneWidget);
        await tester.ensureVisible(find.text('Home'));
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        // Daily Challenge second, same day: must not extend the streak
        // again.
        await tester.ensureVisible(find.text('Daily Challenge'));
        await tester.tap(find.text('Daily Challenge'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(
          find.textContaining('Today already counted · 1-day streak'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a paid hint in the Daily Challenge still costs 20 coins', (
      tester,
    ) async {
      final repo = _FakeWordRepository()
        ..allowedWordsByLength[4] = {'lace', 'mace'}
        ..secretWordsByLengthAndDifficulty[(4, GameDifficulty.common)] = [
          'lace',
        ];
      await tester.pumpWidget(
        CowBullApp(wordRepository: repo, clock: FakeLocalDateProvider(today())),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Daily Challenge'));
      await tester.tap(find.text('Daily Challenge'));
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Hint'));
      await tester.tap(find.textContaining('Hint').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('20 coins'), findsWidgets);
      await tester.tap(find.text('Use 20 Coins'));
      await tester.pumpAndSettle();

      expect(find.text('80'), findsOneWidget);
    });

    testWidgets(
      'sharing the Daily Challenge result shares a DailyChallengeShareCard '
      'with the official date, and never the secret word — even after a '
      'practice replay',
      (tester) async {
        // A tall viewport: the completed view's content (outcome card, the
        // Milestone 20 Daily Challenge replay notice on the second win,
        // guess history, and the Share Challenge action) no longer fits
        // comfortably in the default 800x600 test surface without the
        // action landing flush against the bottom edge, where a `tap()`
        // computed at its exact center can miss it entirely.
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _FakeWordRepository()
          ..wordsByLength[4] = 'lace'
          ..secretWordsByLengthAndDifficulty[(4, GameDifficulty.common)] = [
            'lace',
          ];
        final renderer = FakeShareCardRenderer();
        final service = FakeShareCardService();

        await tester.pumpWidget(
          CowBullApp(
            wordRepository: repo,
            clock: FakeLocalDateProvider(today()),
            shareCardRenderer: renderer,
            shareCardService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Daily Challenge'));
        await tester.tap(find.text('Daily Challenge'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        await tester.ensureVisible(find.text('Share Challenge'));
        await tester.tap(find.text('Share Challenge'));
        await pumpForPreviewToOpen(tester);
        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();

        expect(renderer.renderedCards, hasLength(1));
        final officialCard =
            renderer.renderedCards.single as DailyChallengeShareCard;
        expect(officialCard.data.dateLabel, '18 JULY 2026');
        expect(officialCard.data.attemptsUsed, 1);
        expect(service.calls, hasLength(1));
        final officialCaption = service.calls.single.caption;
        expect(officialCaption.toLowerCase(), isNot(contains('lace')));

        // A practice replay wins in fewer attempts (immediately), but
        // sharing must still reflect the official first completion above,
        // not this replay.
        await tester.ensureVisible(find.text('Replay'));
        await tester.tap(find.text('Replay'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        await tester.ensureVisible(find.text('Share Challenge'));
        await tester.tap(find.text('Share Challenge'));
        await pumpForPreviewToOpen(tester);
        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();

        expect(renderer.renderedCards, hasLength(2));
        final replayCard =
            renderer.renderedCards.last as DailyChallengeShareCard;
        expect(replayCard.data, officialCard.data);
        expect(service.calls, hasLength(2));
        expect(service.calls.last.caption, officialCaption);
      },
    );
  });

  group('Milestone 20: abandoning the Daily Challenge', () {
    LocalDate today() => LocalDate(year: 2026, month: 7, day: 18);

    testWidgets(
      'leaving the Daily Challenge after an accepted guess does not record '
      'a completion, award coins, or update the streak',
      (tester) async {
        final repo = _FakeWordRepository()
          ..wordsByLength[4] = 'lace'
          ..allowedWordsByLength[4] = {'lace', 'race'}
          ..secretWordsByLengthAndDifficulty[(4, GameDifficulty.common)] = [
            'lace',
          ];
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: repo,
            clock: FakeLocalDateProvider(today()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Daily Challenge'));
        await tester.tap(find.text('Daily Challenge'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'race');
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        // Leaving now (one guess accepted, game still active) must show the
        // leave confirmation, then actually pop once confirmed.
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Leave this game?'), findsOneWidget);
        await tester.tap(find.text('Leave'));
        await tester.pumpAndSettle();

        expect(find.text('Not played'), findsOneWidget);
        expect(find.text('100'), findsOneWidget); // coin balance untouched
        expect(find.text('0-day streak'), findsOneWidget);
      },
    );
  });

  group('Milestone 19: coin rewards', () {
    Future<void> enterAndSubmit(WidgetTester tester, String guess) async {
      await tester.enterText(find.byType(TextField), guess);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
    }

    LocalDate today() => LocalDate(year: 2026, month: 7, day: 18);

    testWidgets(
      'an Easy no-hint win earns 15 coins (10 base + 5 no-hint bonus)',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        await tester.pumpWidget(CowBullApp(wordRepository: repo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Easy'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(find.text('You won!'), findsOneWidget);
        expect(find.text('Coins earned'), findsOneWidget);
        expect(find.text('+15'), findsOneWidget);
        expect(find.text('Easy win'), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);
        expect(find.text('No-hint bonus'), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
        expect(find.text('115'), findsOneWidget);
      },
    );

    testWidgets(
      'a Medium-difficulty win that used a hint earns only the 15-coin '
      'base — no no-hint bonus',
      (tester) async {
        final repo = _FakeWordRepository()
          ..wordsByLength[4] = 'lace'
          ..allowedWordsByLength[4] = {'lace', 'mace'};
        await tester.pumpWidget(CowBullApp(wordRepository: repo));
        await tester.pumpAndSettle();

        // Medium is the default difficulty; no tap needed.
        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.lightbulb_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use 20 Coins'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(find.text('You won!'), findsOneWidget);
        expect(find.text('Coins earned'), findsOneWidget);
        expect(find.text('Medium win'), findsOneWidget);
        expect(find.textContaining('No-hint bonus'), findsNothing);
        // The header total and the (only) base-win line both read "+15",
        // since there is no separate no-hint-bonus line to distinguish them.
        expect(find.text('+15'), findsNWidgets(2));
        // 100 - 20 (hint) + 15 (reward) = 95.
        expect(find.text('95'), findsOneWidget);
      },
    );

    testWidgets(
      'a Hard no-hint win earns 25 coins (20 base + 5 no-hint bonus)',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        await tester.pumpWidget(CowBullApp(wordRepository: repo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Hard'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(find.text('Coins earned'), findsOneWidget);
        expect(find.text('+25'), findsOneWidget);
        expect(find.text('Hard win'), findsOneWidget);
        expect(find.text('+20'), findsOneWidget);
        expect(find.text('No-hint bonus'), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
        expect(find.text('125'), findsOneWidget);
      },
    );

    testWidgets('a loss earns 0 coins and shows no coin-reward line', (
      tester,
    ) async {
      final repo = _FakeWordRepository()
        ..wordsByLength[4] = 'lace'
        ..allowedWordsByLength[4] = {'lace', 'mock'};
      await tester.pumpWidget(CowBullApp(wordRepository: repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await enterAndSubmit(tester, 'mock');
      }

      expect(find.text('Not solved'), findsOneWidget);
      expect(find.textContaining('Coins earned'), findsNothing);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('abandoning an in-progress game earns no coins', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      await tester.pumpWidget(CowBullApp(wordRepository: repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets(
      'restarting after a win grants a second, independent coin reward — '
      'rewards are exactly once per completion, never skipped on replay of '
      'an ordinary game',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        await tester.pumpWidget(CowBullApp(wordRepository: repo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Easy'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');
        expect(find.text('115'), findsOneWidget);

        await tester.tap(find.text('Play Again'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(find.text('130'), findsOneWidget);
      },
    );

    testWidgets('navigating away after a completed win does not grant the coin '
        'reward again', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      await tester.pumpWidget(CowBullApp(wordRepository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');
      expect(find.text('115'), findsOneWidget);

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('115'), findsOneWidget);
    });

    testWidgets(
      'the official (first) Daily Challenge win earns the Medium reward '
      'plus the no-hint bonus plus the official bonus (15 + 5 + 10 = 30)',
      (tester) async {
        final repo = _FakeWordRepository()
          ..wordsByLength[4] = 'lace'
          ..secretWordsByLengthAndDifficulty[(4, GameDifficulty.common)] = [
            'lace',
          ];
        await tester.pumpWidget(
          CowBullApp(
            wordRepository: repo,
            clock: FakeLocalDateProvider(today()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Daily Challenge'));
        await tester.tap(find.text('Daily Challenge'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(find.text('You won!'), findsOneWidget);
        expect(find.text('Coins earned'), findsOneWidget);
        expect(find.text('+30'), findsOneWidget);
        expect(find.text('Medium win'), findsOneWidget);
        expect(find.text('+15'), findsOneWidget);
        expect(find.text('No-hint bonus'), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
        expect(find.text('Daily Challenge bonus'), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);
        expect(find.text('130'), findsOneWidget);
      },
    );

    testWidgets('a Daily Challenge replay after the official win earns no '
        'additional coins at all — not just missing the official bonus', (
      tester,
    ) async {
      final repo = _FakeWordRepository()
        ..wordsByLength[4] = 'lace'
        ..secretWordsByLengthAndDifficulty[(4, GameDifficulty.common)] = [
          'lace',
        ];
      await tester.pumpWidget(
        CowBullApp(wordRepository: repo, clock: FakeLocalDateProvider(today())),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Daily Challenge'));
      await tester.tap(find.text('Daily Challenge'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');
      expect(find.text('130'), findsOneWidget);

      await tester.ensureVisible(find.text('Replay'));
      await tester.tap(find.text('Replay'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.text('130'), findsOneWidget);
      expect(find.textContaining('Coins earned'), findsNothing);
    });

    testWidgets('the Statistics screen shows real coin totals accumulated from '
        'gameplay', (tester) async {
      final repo = _FakeWordRepository()
        ..wordsByLength[4] = 'lace'
        ..allowedWordsByLength[4] = {'lace', 'mace'};
      await tester.pumpWidget(
        CowBullApp(
          wordRepository: repo,
          statisticsRepository: FakeStatisticsRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.lightbulb_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use 20 Coins'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');
      // Easy win with a hint used: base 10, no no-hint bonus.
      // Balance: 100 - 20 (hint) + 10 (reward) = 90.

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Statistics'));
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      expect(find.text('Coins'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets(
      'a coin-wallet persistence failure never blocks the win screen or '
      'throws — the reward still shows, from in-memory truth',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final failingStore = FakePreferencesStore()..failSetString = true;
        final coinWallet = CoinWallet(initialBalance: 100, store: failingStore);
        await tester.pumpWidget(
          CowBullApp(wordRepository: repo, coinWallet: coinWallet),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Easy'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(find.text('You won!'), findsOneWidget);
        expect(find.text('Coins earned'), findsOneWidget);
        expect(find.text('+15'), findsOneWidget);
        // The in-memory balance still reflects the reward even though every
        // write to failingStore fails.
        expect(find.text('115'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(coinWallet.debugLastPersistError, isNotNull);
      },
    );
  });
}

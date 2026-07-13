import 'package:cowbullgame/app.dart';
import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<List<String>> loadAllowedWords(int wordLength) async => const [];

  @override
  Future<List<String>> loadSecretWords(
    int wordLength,
    GameDifficulty difficulty,
  ) async => const [];

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

    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsNothing);
    expect(find.textContaining('Bulls & Cows · 4 letters'), findsOneWidget);
  });

  testWidgets('starting a game uses the correct GameConfig for the '
      'selected word length', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[6] = 'garden';
    await tester.pumpWidget(CowBullApp(wordRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('6 letters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bulls & Cows · 6 letters'), findsOneWidget);
    // Attempts limit for 6-letter games (GameConfig.forSelection).
    expect(find.textContaining('20'), findsWidgets);
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

    expect(find.textContaining('Easy'), findsAtLeastNWidgets(1));
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

    expect(find.textContaining('Bulls & Cows · 4 letters'), findsOneWidget);
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

      await tester.ensureVisible(find.text('Return to Home'));
      await tester.tap(find.text('Return to Home'));
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

        await tester.tap(find.text('Restart'));
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

      await tester.ensureVisible(find.text('Return to Home'));
      await tester.tap(find.text('Return to Home'));
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

        expect(find.textContaining('Bulls & Cows · 4 letters'), findsOneWidget);

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
      expect(find.textContaining('Bulls & Cows'), findsOneWidget);
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
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bulls & Cows'), findsOneWidget);
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
}

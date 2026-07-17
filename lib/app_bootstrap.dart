import 'app_settings.dart';
import 'audio_feedback_coordinator.dart';
import 'audio_feedback_settings.dart';
import 'coin_wallet.dart';
import 'core/audio/audioplayers_audio_service.dart';
import 'core/haptics/platform_haptic_service.dart';
import 'core/persistence/preferences_store.dart';
import 'core/persistence/shared_preferences_store.dart';
import 'core/persistence/storage_keys.dart';
import 'core/time/local_date_provider.dart';
import 'features/daily_challenge/controllers/daily_challenge_controller.dart';
import 'features/daily_challenge/data/local_daily_challenge_repository.dart';
import 'features/statistics/data/local_statistics_repository.dart';
import 'features/statistics/data/statistics_repository.dart';
import 'features/streak/controllers/streak_controller.dart';
import 'features/streak/data/local_streak_repository.dart';

/// The app's fully-resolved startup dependencies.
///
/// Built once by [AppBootstrap.load] before `runApp` and handed to
/// [CowBullApp] via constructor injection, so storage and repositories are
/// created exactly once for the app's lifetime — a later `MaterialApp`
/// rebuild never recreates them. Keeps `main.dart` a two-line call: create
/// the bootstrap, then run the app.
class AppBootstrap {
  const AppBootstrap({
    required this.settings,
    required this.statisticsRepository,
    required this.coinWallet,
    required this.audioFeedbackSettings,
    required this.audioFeedback,
    required this.clock,
    required this.streakController,
    required this.dailyChallengeController,
  });

  /// Loads persisted preferences and constructs the shared [PreferencesStore]
  /// once, then builds every startup dependency from it: [AppSettings]
  /// (seeded with the persisted theme preference, so the UI never flashes
  /// the default theme before switching to the persisted one), the
  /// [StatisticsRepository] backing completed-game statistics, the
  /// [CoinWallet] backing the coin balance and hint purchases, and the
  /// [AudioFeedbackSettings]/[AudioFeedbackCoordinator] pair backing sound,
  /// music, and haptic feedback.
  ///
  /// [clock] defaults to [SystemLocalDateProvider] (the device's real local
  /// clock) and is threaded through to [streakController] and
  /// [dailyChallengeController] — and, unchanged, into [AppBootstrap] itself
  /// so the app-level composition root can reuse the exact same clock
  /// instance when starting a new Daily Challenge — so every "today" this
  /// app computes agrees. Overridable only so tests can inject a fixed/fake
  /// clock without touching the real device time.
  static Future<AppBootstrap> load({
    LocalDateProvider clock = const SystemLocalDateProvider(),
  }) async {
    const store = SharedPreferencesStore();
    final settings = await AppSettings.load(store);
    final statisticsRepository = LocalStatisticsRepository(store: store);
    final coinWallet = await CoinWallet.load(store);
    final audioFeedbackSettings = await AudioFeedbackSettings.load(store);
    final audioFeedback = AudioFeedbackCoordinator(
      audioService: AudioPlayersAudioService(),
      hapticService: const PlatformHapticService(),
      settings: audioFeedbackSettings,
    );
    final streakController = await StreakController.load(
      repository: LocalStreakRepository(store: store),
      clock: clock,
    );
    final dailyChallengeController = await DailyChallengeController.load(
      repository: LocalDailyChallengeRepository(store: store),
      clock: clock,
    );
    return AppBootstrap(
      settings: settings,
      statisticsRepository: statisticsRepository,
      coinWallet: coinWallet,
      audioFeedbackSettings: audioFeedbackSettings,
      audioFeedback: audioFeedback,
      clock: clock,
      streakController: streakController,
      dailyChallengeController: dailyChallengeController,
    );
  }

  /// The app-wide theme-preference source, already seeded from persisted
  /// storage. Owned by [CowBullApp] for the app's lifetime.
  final AppSettings settings;

  /// The shared statistics storage, backing the app-owned
  /// `StatisticsController` for the app's lifetime.
  final StatisticsRepository statisticsRepository;

  /// The app-wide coin balance, already seeded from persisted storage (or
  /// initialized to [startingCoinBalance] on first run). Owned by
  /// [CowBullApp] for the app's lifetime.
  final CoinWallet coinWallet;

  /// The app-wide sound-effects/music/haptics preferences, already seeded
  /// from persisted storage. Owned by [CowBullApp] for the app's lifetime.
  final AudioFeedbackSettings audioFeedbackSettings;

  /// The app-wide audio/haptic feedback coordinator, already wired to
  /// [audioFeedbackSettings] and a real, playback-capable [AudioService]/
  /// [HapticService] pair. Owned by [CowBullApp] for the app's lifetime.
  final AudioFeedbackCoordinator audioFeedback;

  /// The single app-wide source of "today", shared by [streakController],
  /// [dailyChallengeController], and the composition root itself whenever it
  /// needs today's date (e.g. to start a new Daily Challenge).
  final LocalDateProvider clock;

  /// The app-wide daily-play-streak state, already seeded from persisted
  /// storage (or [StreakState.empty] on a fresh install). Owned by
  /// [CowBullApp] for the app's lifetime.
  final StreakController streakController;

  /// The app-wide "today's Daily Challenge" state, already seeded from
  /// persisted storage. Owned by [CowBullApp] for the app's lifetime.
  final DailyChallengeController dailyChallengeController;

  /// Deletes every app-owned local storage key — currently
  /// [StorageKeys.themePreference], [StorageKeys.statistics],
  /// [StorageKeys.coinBalance], [StorageKeys.soundEffectsEnabled],
  /// [StorageKeys.musicEnabled], [StorageKeys.hapticsEnabled],
  /// [StorageKeys.streak], and [StorageKeys.dailyChallengeResults], and
  /// nothing else — from [store]. Used by the startup failure screen's
  /// "Reset local data" action so a corrupted or otherwise unrecoverable
  /// local storage state can be cleared without reinstalling the app.
  ///
  /// Removing a key that was never set is not an error (see
  /// [PreferencesStore.remove]), so this is safe to call even when nothing
  /// has been persisted yet. Never touches any storage key this app does
  /// not itself own.
  static Future<void> resetLocalData(PreferencesStore store) async {
    await store.remove(StorageKeys.themePreference);
    await store.remove(StorageKeys.statistics);
    await store.remove(StorageKeys.coinBalance);
    await store.remove(StorageKeys.soundEffectsEnabled);
    await store.remove(StorageKeys.musicEnabled);
    await store.remove(StorageKeys.hapticsEnabled);
    await store.remove(StorageKeys.streak);
    await store.remove(StorageKeys.dailyChallengeResults);
  }
}

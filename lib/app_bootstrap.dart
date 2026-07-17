import 'app_settings.dart';
import 'coin_wallet.dart';
import 'core/persistence/preferences_store.dart';
import 'core/persistence/shared_preferences_store.dart';
import 'core/persistence/storage_keys.dart';
import 'features/statistics/data/local_statistics_repository.dart';
import 'features/statistics/data/statistics_repository.dart';

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
  });

  /// Loads persisted preferences and constructs the shared [PreferencesStore]
  /// once, then builds every startup dependency from it: [AppSettings]
  /// (seeded with the persisted theme preference, so the UI never flashes
  /// the default theme before switching to the persisted one), the
  /// [StatisticsRepository] backing completed-game statistics, and the
  /// [CoinWallet] backing the coin balance and hint purchases.
  static Future<AppBootstrap> load() async {
    const store = SharedPreferencesStore();
    final settings = await AppSettings.load(store);
    final statisticsRepository = LocalStatisticsRepository(store: store);
    final coinWallet = await CoinWallet.load(store);
    return AppBootstrap(
      settings: settings,
      statisticsRepository: statisticsRepository,
      coinWallet: coinWallet,
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

  /// Deletes every app-owned local storage key — currently
  /// [StorageKeys.themePreference], [StorageKeys.statistics], and
  /// [StorageKeys.coinBalance], and nothing else — from [store]. Used by
  /// the startup failure screen's "Reset local data" action so a corrupted
  /// or otherwise unrecoverable local storage state can be cleared without
  /// reinstalling the app.
  ///
  /// Removing a key that was never set is not an error (see
  /// [PreferencesStore.remove]), so this is safe to call even when nothing
  /// has been persisted yet. Never touches any storage key this app does
  /// not itself own.
  static Future<void> resetLocalData(PreferencesStore store) async {
    await store.remove(StorageKeys.themePreference);
    await store.remove(StorageKeys.statistics);
    await store.remove(StorageKeys.coinBalance);
  }
}

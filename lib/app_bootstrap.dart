import 'app_settings.dart';
import 'core/persistence/preferences_store.dart';
import 'core/persistence/shared_preferences_store.dart';
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
  });

  /// Loads persisted preferences and constructs the shared [PreferencesStore]
  /// once, then builds every startup dependency from it: [AppSettings]
  /// (seeded with the persisted theme preference, so the UI never flashes
  /// the default theme before switching to the persisted one) and the
  /// [StatisticsRepository] backing completed-game statistics.
  static Future<AppBootstrap> load() async {
    const store = SharedPreferencesStore();
    final settings = await AppSettings.load(store);
    final statisticsRepository = LocalStatisticsRepository(store: store);
    return AppBootstrap(
      settings: settings,
      statisticsRepository: statisticsRepository,
    );
  }

  /// The app-wide theme-preference source, already seeded from persisted
  /// storage. Owned by [CowBullApp] for the app's lifetime.
  final AppSettings settings;

  /// The shared statistics storage, backing the app-owned
  /// `StatisticsController` for the app's lifetime.
  final StatisticsRepository statisticsRepository;
}

/// The Daily Challenge card's display state on the Home screen.
///
/// Deliberately has no "in progress" value: this milestone does not persist
/// an unfinished game of any kind, so there is no reliable signal an
/// in-progress state could be based on — an unfinished Daily Challenge
/// simply restarts from the beginning if the app is closed, exactly like an
/// unfinished normal game. Feature-local to `home` (rather than the shared
/// `models/` layer) since only [HomeScreen] itself renders it — the
/// app-level composition root computes this value from
/// `DailyChallengeController.officialResultToday` but does not need the type
/// anywhere else.
enum DailyChallengeCardStatus {
  /// Today's Daily Challenge has not been completed yet.
  notPlayed,

  /// Today's official Daily Challenge attempt was won.
  completedWon,

  /// Today's official Daily Challenge attempt was completed but not solved.
  completedNotSolved,
}

/// A presentation-safe snapshot of a streak update, decoupled from
/// `features/streak`'s own `StreakUpdateResult`.
///
/// Lives in this shared `models/` layer (see CLAUDE.md) because it is used
/// by two places: the `game` feature's completed-game screen, which shows a
/// restrained one-time animation when a streak was just started or
/// extended, and the app-level composition root, which maps
/// `features/streak`'s `StreakUpdateResult` onto this neutral type — the
/// same pattern [DifficultyOption] (`difficulty_selection.dart`) already
/// uses so `home` never has to import `game`. Keeping this here means the
/// `game` feature never has to import the `streak` feature just to display
/// what happened to it.
enum StreakFeedbackKind {
  /// Today started a new streak (the very first qualifying day ever, or the
  /// first day after a gap).
  started,

  /// Today extended a streak already in progress.
  extended,

  /// A qualifying game was already completed earlier today; this
  /// completion changed nothing.
  alreadyCounted,
}

/// What happened to the streak as a result of one completed game, and the
/// resulting streak length — enough for presentation code to render text
/// like "Streak started: 1 day" or "Today already counted · 4-day streak"
/// without needing anything else about how the streak is computed or
/// stored.
class StreakFeedback {
  const StreakFeedback({required this.kind, required this.currentStreak});

  final StreakFeedbackKind kind;

  /// The streak length after this completion was applied.
  final int currentStreak;
}

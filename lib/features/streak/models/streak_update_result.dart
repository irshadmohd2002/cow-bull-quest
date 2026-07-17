import 'streak_state.dart';

/// The outcome of `StreakService.recordQualifyingDay`: what happened to the
/// streak as a result of today's qualifying completion, together with the
/// resulting [state].
///
/// A sealed hierarchy so presentation code can exhaustively `switch` over
/// exactly one source of truth for "what should I tell the player just
/// happened to their streak", matching the pattern `GameControllerState`/
/// `HintOutcome` already use elsewhere in this app.
sealed class StreakUpdateResult {
  const StreakUpdateResult(this.state);

  /// The streak state after this update.
  final StreakState state;
}

/// Today is the first day of a new streak — either the very first qualifying
/// day ever, or the first day after one or more calendar days were missed
/// (a reset). [StreakState.currentStreak] is always `1`.
final class StreakStarted extends StreakUpdateResult {
  const StreakStarted(super.state);
}

/// Today is a consecutive qualifying day immediately after
/// [StreakState.lastQualifyingDate]'s previous value, so the streak grew by
/// one day.
final class StreakExtended extends StreakUpdateResult {
  const StreakExtended(super.state);
}

/// A qualifying game was already completed earlier today; this call changed
/// nothing. [state] is identical to the state passed in.
final class StreakAlreadyCounted extends StreakUpdateResult {
  const StreakAlreadyCounted(super.state);
}

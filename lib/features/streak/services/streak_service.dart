import 'dart:math' as math;

import '../../../core/time/local_date.dart';
import '../models/streak_state.dart';
import '../models/streak_update_result.dart';

/// Computes streak transitions from a previous [StreakState] and today's
/// [LocalDate].
///
/// Stateless and deterministic — no persistence, no [DateTime.now], no
/// widgets — so every rule (same-day no-op, consecutive-day increment,
/// gap reset, longest-streak monotonicity) is directly unit-testable with
/// fixed inputs. `StreakController` is the only thing that calls this; it
/// owns persisting the resulting [StreakState].
class StreakService {
  const StreakService();

  /// Applies one qualifying completion on [today] to [previous].
  ///
  /// - If [today] equals [previous].[StreakState.lastQualifyingDate], this is
  ///   a no-op: returns [StreakAlreadyCounted] with [previous] unchanged —
  ///   multiple completions on the same calendar day only ever count once.
  /// - If [today] is exactly the day after [previous].[StreakState.lastQualifyingDate],
  ///   the streak extends by one day: returns [StreakExtended].
  /// - Otherwise (no prior qualifying day, or one or more calendar days were
  ///   missed), the streak restarts at `1`: returns [StreakStarted].
  ///
  /// [StreakState.longestStreak] is updated to the new [StreakState.currentStreak]
  /// whenever that exceeds the previous longest streak, and is otherwise left
  /// unchanged — it never decreases.
  StreakUpdateResult recordQualifyingDay({
    required StreakState previous,
    required LocalDate today,
  }) {
    if (previous.lastQualifyingDate == today) {
      return StreakAlreadyCounted(previous);
    }

    final isConsecutiveDay =
        previous.lastQualifyingDate != null &&
        previous.lastQualifyingDate!.nextDay == today;

    final newCurrentStreak = isConsecutiveDay ? previous.currentStreak + 1 : 1;
    final newLongestStreak = math.max(previous.longestStreak, newCurrentStreak);

    final newState = StreakState(
      currentStreak: newCurrentStreak,
      longestStreak: newLongestStreak,
      lastQualifyingDate: today,
    );

    return isConsecutiveDay
        ? StreakExtended(newState)
        : StreakStarted(newState);
  }
}

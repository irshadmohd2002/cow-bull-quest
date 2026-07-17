import '../models/game_difficulty.dart';

/// The coin cost of a paid hint, everywhere one is charged.
const int hintCoinCost = 20;

/// Difficulty-specific hint limits and pricing.
///
/// Easy and Medium (`GameDifficulty.common`) each allow at most one hint
/// per game, always costing [hintCoinCost] coins. Hard allows up to two:
/// the first is free, the second costs [hintCoinCost] coins. Never affects
/// scoring, guess validation, or attempt limits — purely a hint-eligibility
/// and pricing policy, kept separate from [HintService] (which only
/// decides *which letter* the next hint reveals, never how many are
/// allowed or what they cost).
class HintPolicy {
  const HintPolicy();

  /// The maximum number of hints allowed per game for [difficulty].
  int maxHints(GameDifficulty difficulty) => switch (difficulty) {
    GameDifficulty.easy => 1,
    GameDifficulty.common => 1,
    GameDifficulty.hard => 2,
  };

  /// The coin cost of the next hint, given [hintsUsed] hints already used
  /// this game (so this call describes hint number `hintsUsed + 1`).
  ///
  /// Returns `0` (free) only for Hard's first hint (`difficulty == hard`
  /// and `hintsUsed == 0`); returns [hintCoinCost] for every other hint,
  /// regardless of difficulty.
  int costFor(GameDifficulty difficulty, int hintsUsed) {
    if (difficulty == GameDifficulty.hard && hintsUsed == 0) return 0;
    return hintCoinCost;
  }
}

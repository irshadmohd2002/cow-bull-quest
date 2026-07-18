import '../models/game_difficulty.dart';

/// Coins awarded for winning at [GameDifficulty.easy].
const int easyWinCoinReward = 10;

/// Coins awarded for winning at [GameDifficulty.common] (labeled "Medium" in
/// the UI).
const int mediumWinCoinReward = 15;

/// Coins awarded for winning at [GameDifficulty.hard].
const int hardWinCoinReward = 20;

/// Flat bonus added to a win's reward when the game was won without ever
/// using a hint (`hintsUsed == 0`).
const int noHintWinCoinBonus = 5;

/// Flat bonus added to a Daily Challenge win's reward when this completion
/// is the day's first (official) one — see [CoinRewardCalculator.rewardForDailyChallenge].
const int dailyChallengeOfficialWinCoinBonus = 10;

/// An itemized, immutable breakdown of one completed game's Milestone 19
/// coin reward — every line the reward is made of, not just the total.
///
/// Returned by [CoinRewardCalculator] instead of a bare `int` so presentation
/// code (the completed-game view) can show each line separately ("Easy win
/// +10", "No-hint bonus +5") without re-deriving them from raw game state
/// itself, and so a caller deciding *whether* anything was earned at all can
/// ask [rewarded] rather than re-checking `total > 0` inline everywhere.
class CoinRewardBreakdown {
  const CoinRewardBreakdown({
    required this.baseWinReward,
    required this.noHintBonus,
    required this.dailyChallengeBonus,
  });

  /// A breakdown representing no reward at all — every line `0`. Returned
  /// for a loss, an abandoned/restarted game (which never reaches a
  /// calculator call in the first place), or a Daily Challenge replay.
  static const CoinRewardBreakdown none = CoinRewardBreakdown(
    baseWinReward: 0,
    noHintBonus: 0,
    dailyChallengeBonus: 0,
  );

  /// The difficulty-based win amount ([easyWinCoinReward]/
  /// [mediumWinCoinReward]/[hardWinCoinReward]), or `0` for a loss/replay.
  final int baseWinReward;

  /// [noHintWinCoinBonus] if this win used no hints, else `0`.
  final int noHintBonus;

  /// [dailyChallengeOfficialWinCoinBonus] for an official Daily Challenge
  /// win, else `0` (including for every non-Daily-Challenge game, which
  /// never has this bonus at all).
  final int dailyChallengeBonus;

  /// The sum of every line above — the actual amount [CoinWallet.earn]
  /// should be called with.
  int get totalCoinsEarned => baseWinReward + noHintBonus + dailyChallengeBonus;

  /// Whether this breakdown represents an actual reward. Equivalent to
  /// `totalCoinsEarned > 0`, exposed as its own getter so call sites read as
  /// "was anything earned" rather than repeating the arithmetic.
  bool get rewarded => totalCoinsEarned > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoinRewardBreakdown &&
          other.baseWinReward == baseWinReward &&
          other.noHintBonus == noHintBonus &&
          other.dailyChallengeBonus == dailyChallengeBonus);

  @override
  int get hashCode =>
      Object.hash(baseWinReward, noHintBonus, dailyChallengeBonus);

  @override
  String toString() =>
      'CoinRewardBreakdown(baseWinReward: $baseWinReward, '
      'noHintBonus: $noHintBonus, dailyChallengeBonus: $dailyChallengeBonus, '
      'totalCoinsEarned: $totalCoinsEarned)';
}

/// Milestone 19's coin-reward rules: how many coins a finished game earns.
///
/// Pure and Flutter-free (see CLAUDE.md's `services/` guidance) so it is
/// unit-testable without a widget tester and reusable from the app-level
/// composition root, which is the only place with enough context (the
/// finished [GameDifficulty], hint usage, and — for the Daily Challenge —
/// whether this completion is today's official one) to call it. Neither
/// method here ever runs for a restarted or abandoned game: the composition
/// root only calls a `GameController.onGameCompleted` hook, which itself
/// only fires once a session has genuinely transitioned to won or lost (see
/// `GameController`'s own doc), so "restart/abandon earns nothing" is
/// already guaranteed before either method below is ever reached — a loss
/// still reaches it, and is handled by returning [CoinRewardBreakdown.none].
class CoinRewardCalculator {
  const CoinRewardCalculator();

  /// Coins earned by a finished, ordinary (non-Daily-Challenge) game.
  ///
  /// [CoinRewardBreakdown.none] for a loss (`won == false`). For a win, the
  /// difficulty-based base reward plus [noHintWinCoinBonus] if [hintsUsed]
  /// is `0`. [CoinRewardBreakdown.dailyChallengeBonus] is always `0` here.
  CoinRewardBreakdown rewardForGame({
    required bool won,
    required GameDifficulty difficulty,
    required int hintsUsed,
  }) {
    if (!won) return CoinRewardBreakdown.none;
    return CoinRewardBreakdown(
      baseWinReward: _baseWinReward(difficulty),
      noHintBonus: _noHintBonus(hintsUsed),
      dailyChallengeBonus: 0,
    );
  }

  /// Coins earned by a finished Daily Challenge attempt.
  ///
  /// The Daily Challenge is always played at [GameDifficulty.common].
  /// [CoinRewardBreakdown.none] unless [won] and [isOfficial] are both
  /// `true` — a loss earns nothing, exactly like [rewardForGame], and so
  /// does *any* outcome of a replay (`isOfficial == false`): only the
  /// calendar day's first completion is ever official (see
  /// `DailyChallengeController.recordIfFirst`), and a replay earning coins
  /// of its own would let a player farm unlimited coins by replaying a
  /// challenge whose secret word they already know from the official
  /// attempt — not just fail to claim [dailyChallengeOfficialWinCoinBonus],
  /// which is the one rule the milestone states explicitly, but the whole
  /// reward.
  ///
  /// An official win earns [mediumWinCoinReward] (the Daily Challenge's
  /// fixed difficulty) as [CoinRewardBreakdown.baseWinReward], plus
  /// [noHintWinCoinBonus] if [hintsUsed] is `0`, plus
  /// [dailyChallengeOfficialWinCoinBonus] as
  /// [CoinRewardBreakdown.dailyChallengeBonus].
  CoinRewardBreakdown rewardForDailyChallenge({
    required bool won,
    required bool isOfficial,
    required int hintsUsed,
  }) {
    if (!won || !isOfficial) return CoinRewardBreakdown.none;
    return CoinRewardBreakdown(
      baseWinReward: _baseWinReward(GameDifficulty.common),
      noHintBonus: _noHintBonus(hintsUsed),
      dailyChallengeBonus: dailyChallengeOfficialWinCoinBonus,
    );
  }

  int _baseWinReward(GameDifficulty difficulty) => switch (difficulty) {
    GameDifficulty.easy => easyWinCoinReward,
    GameDifficulty.common => mediumWinCoinReward,
    GameDifficulty.hard => hardWinCoinReward,
  };

  int _noHintBonus(int hintsUsed) => hintsUsed == 0 ? noHintWinCoinBonus : 0;
}

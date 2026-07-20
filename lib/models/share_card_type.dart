/// The three positive sharing moments the app can render a branded PNG share
/// card for. Deliberately exhaustive: there is no "loss" or "not solved"
/// member — a losing game or a lost official Daily Challenge never has a
/// share card at all, so no code path should ever need to represent one.
enum ShareCardType {
  /// Winning a normal Easy, Medium, or Hard game.
  normalWin,

  /// Winning the official (first-of-the-day) Daily Challenge attempt.
  dailyChallengeWin,

  /// The player's current daily-play streak, while it is at least one day.
  streak,
}

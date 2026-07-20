import '../models/daily_challenge_share_data.dart';
import '../models/normal_win_share_data.dart';
import '../models/streak_share_data.dart';

/// Builds the short, spoiler-free caption sent alongside a share card's PNG.
///
/// Pure and deterministic — no platform calls, no randomness — so the same
/// input always formats to the exact same caption. Deliberately never reads
/// a secret word, a guessed word, or a wallet balance: each caption is built
/// only from the neutral `*ShareData` the card itself was rendered from.
class ShareCaptionFormatter {
  const ShareCaptionFormatter();

  static const String _appName = 'Cow Bull Quest';

  /// "Cow Bull Quest\nSolved in 4/10 attempts.\nCan you solve it too?"
  String normalWin(NormalWinShareData data) =>
      '$_appName\n${data.attemptsLabel}.\nCan you solve it too?';

  /// "Cow Bull Quest Daily Challenge\nSolved in 4/10 attempts.\nCan you beat
  /// today's challenge?"
  String dailyChallengeWin(DailyChallengeShareData data) =>
      '$_appName Daily Challenge\n'
      '${data.attemptsLabel}.\n'
      "Can you beat today's challenge?";

  /// "Cow Bull Quest\nI reached a 7-day streak.\nWhat's your biggest
  /// streak?"
  String streak(StreakShareData data) =>
      '$_appName\n'
      'I reached a ${data.currentStreak}-day streak.\n'
      "What's your biggest streak?";
}

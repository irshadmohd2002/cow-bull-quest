/// Small, pure text helpers shared by [NormalWinShareData] and
/// [DailyChallengeShareData] so both models format identical fields
/// ("Solved in X/Y attempts", "No hints used"/"N hint(s) used") the exact
/// same way rather than duplicating the pluralization rules twice.
library;

/// "Solved in 4/10 attempts" for any [attemptsUsed]/[maxAttempts].
String shareCardAttemptsLabel(int attemptsUsed, int maxAttempts) =>
    'Solved in $attemptsUsed/$maxAttempts attempts';

/// "No hints used", "1 hint used", or "N hints used".
String shareCardHintsLabel(int hintsUsed) => switch (hintsUsed) {
  0 => 'No hints used',
  1 => '1 hint used',
  _ => '$hintsUsed hints used',
};

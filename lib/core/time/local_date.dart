/// A normalized local calendar date: year/month/day only, with no time-of-day
/// or timezone component.
///
/// Every streak and Daily Challenge computation in this app compares
/// *calendar dates*, not elapsed 24-hour periods or timestamps — two
/// [DateTime]s eleven hours apart can be the same calendar day or different
/// calendar days depending on the time of day, which is exactly the
/// ambiguity this type removes by construction. Equality and [compareTo]
/// only ever consider [year]/[month]/[day].
///
/// Internally, every date computation (day-of-week-independent arithmetic
/// like [nextDay] and [epochDay]) goes through [DateTime.utc] rather than
/// the local-timezone [DateTime.new]/[DateTime.now] constructors, so
/// calendar-day arithmetic (month-end, year-end, and leap-day rollovers) is
/// never perturbed by daylight-saving transitions in the device's local
/// timezone. [LocalDate] itself has no notion of "now" — see
/// `LocalDateProvider` for the one seam that reads the current date, kept
/// separate so streak/Daily Challenge logic never calls [DateTime.now]
/// directly and tests can supply a fixed date deterministically.
///
/// **Changing the device clock** (manually setting the date/time backwards
/// or forwards) changes what this app considers "today" for both the daily
/// streak and the Daily Challenge, since both are computed entirely
/// on-device with no internet time or server validation — this is a
/// documented limitation of an offline-only feature, not a bug.
class LocalDate implements Comparable<LocalDate> {
  /// Throws [ArgumentError] if [month] is not 1-12 or [day] is not a valid
  /// day for [year]/[month] (including leap-day validity for February).
  LocalDate({required this.year, required this.month, required this.day}) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be 1-12');
    }
    final utc = DateTime.utc(year, month, day);
    if (utc.year != year || utc.month != month || utc.day != day) {
      throw ArgumentError.value(day, 'day', 'not a valid day for $year-$month');
    }
  }

  /// The calendar date portion of [dateTime], in whatever timezone
  /// [dateTime] itself already represents (local or UTC) — this simply reads
  /// off [DateTime.year]/[DateTime.month]/[DateTime.day] as-is; it never
  /// converts timezones itself.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(year: dateTime.year, month: dateTime.month, day: dateTime.day);

  /// Parses an ISO-8601 date string (`YYYY-MM-DD`), or returns `null` if
  /// [value] is not a well-formed, valid calendar date in that exact format.
  static LocalDate? tryParse(String value) {
    final match = _isoPattern.firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    try {
      return LocalDate(year: year, month: month, day: day);
    } on ArgumentError {
      return null;
    }
  }

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// The next calendar date after this one. Correctly rolls over month-end,
  /// year-end, and leap-day boundaries (e.g. Feb 28 2027 → Mar 1 2027, Feb 28
  /// 2028 → Feb 29 2028, Dec 31 2026 → Jan 1 2027) since it is computed via
  /// [DateTime.utc]'s own field-overflow normalization rather than manual
  /// month-length arithmetic.
  LocalDate get nextDay =>
      LocalDate.fromDateTime(DateTime.utc(year, month, day + 1));

  /// The number of whole days between the Unix epoch (1970-01-01) and this
  /// date; negative for dates before the epoch. Used as the sole input to
  /// deterministic date-based selection (see `DailyChallengeService`) instead
  /// of `String.hashCode` (whose result is only guaranteed stable within one
  /// run, not across Dart runtimes/versions): plain integer subtraction of
  /// two [DateTime.utc] instants is stable, documented VM/web-compatible
  /// arithmetic with no such caveat.
  int get epochDay => DateTime.utc(year, month, day).difference(_epoch).inDays;

  static final DateTime _epoch = DateTime.utc(1970);

  /// Renders this date as `YYYY-MM-DD`, matching [tryParse]'s expected
  /// input.
  String toIso8601String() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDate &&
          other.year == year &&
          other.month == month &&
          other.day == day);

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  int compareTo(LocalDate other) => epochDay.compareTo(other.epochDay);

  @override
  String toString() => toIso8601String();
}

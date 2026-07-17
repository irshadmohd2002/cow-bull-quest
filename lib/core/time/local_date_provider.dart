import 'local_date.dart';

/// Supplies "today", as a normalized [LocalDate], to any business logic that
/// needs to know the current calendar date — the daily streak
/// (`features/streak`) and the Daily Challenge (`features/daily_challenge`).
///
/// Business logic must never call [DateTime.now] directly: depending on it
/// requires a real device clock in every test, and makes it impossible to
/// deterministically test date-boundary behavior (a day rollover, a month
/// end, a leap day). Injecting this abstraction instead lets tests supply a
/// fixed or controlled date (see `test/support/fake_local_date_provider.dart`)
/// while the shipped app always uses [SystemLocalDateProvider], which reads
/// the device's real local clock.
abstract class LocalDateProvider {
  /// The current local calendar date.
  LocalDate today();
}

/// The real [LocalDateProvider]: reads [DateTime.now], the device's local
/// clock.
///
/// Because this reads the *local* clock with no internet time or server
/// validation, manually changing the device's date/time changes what this
/// app considers "today" for both the daily streak and the Daily Challenge —
/// an inherent, documented limitation of computing both features entirely
/// offline (see [LocalDate]'s class-level doc).
class SystemLocalDateProvider implements LocalDateProvider {
  const SystemLocalDateProvider();

  @override
  LocalDate today() => LocalDate.fromDateTime(DateTime.now());
}

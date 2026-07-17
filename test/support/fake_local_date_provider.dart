import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/core/time/local_date_provider.dart';

/// Controllable [LocalDateProvider] fake so tests can exercise streak/Daily
/// Challenge date-boundary behavior (same day, next day, a gap, month/year/
/// leap-day transitions) deterministically, without a real device clock.
class FakeLocalDateProvider implements LocalDateProvider {
  FakeLocalDateProvider(this._today);

  LocalDate _today;

  @override
  LocalDate today() => _today;

  /// Moves the fake clock to [date], as if the device's calendar date
  /// changed to it.
  void setToday(LocalDate date) => _today = date;
}

import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/core/time/local_date_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SystemLocalDateProvider reflects the real local clock', () {
    const provider = SystemLocalDateProvider();
    final expected = LocalDate.fromDateTime(DateTime.now());
    // Compared right after each other; both derive from the same instant to
    // the minute, so they must agree on the calendar date under test.
    expect(provider.today(), expected);
  });
}

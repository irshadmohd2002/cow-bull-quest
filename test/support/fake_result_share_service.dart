import 'package:cowbullgame/core/sharing/result_share_service.dart';

/// In-memory [ResultShareService] fake so tests can assert exactly what text
/// (and subject) was shared, how many times, and force a simulated share
/// failure — without ever opening a real platform share sheet.
class FakeResultShareService implements ResultShareService {
  /// Every `shareText` call, in call order.
  final List<({String text, String? subject})> calls = [];

  /// If set, every call throws this error instead of recording normally —
  /// lets a test force a share failure to prove it's handled gracefully.
  Object? failWith;

  /// If set, `shareText` awaits this before completing (and before
  /// recording into [calls]) instead of resolving immediately. A real
  /// platform share call always takes some real time; this lets a test hold
  /// a share deterministically "in flight" — e.g. to verify a rapid second
  /// tap is guarded against — rather than racing Dart's microtask queue
  /// against how fast an instantly-resolving fake completes.
  Future<void>? delay;

  @override
  Future<void> shareText({required String text, String? subject}) async {
    final pending = delay;
    if (pending != null) await pending;
    calls.add((text: text, subject: subject));
    final error = failWith;
    if (error != null) throw error;
  }
}

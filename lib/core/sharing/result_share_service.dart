/// Opens the platform's system share sheet for a piece of already-formatted
/// text.
///
/// A pure platform-invocation abstraction, mirroring [AudioService]'s role
/// for sound: it knows nothing about game rules, result formatting, or
/// whether the share sheet was actually completed by the user — it only
/// knows how to hand text (and an optional subject, used by
/// mail-style share targets) to the platform's native share UI. App code and
/// features depend on this interface rather than on `package:share_plus`
/// directly, so the concrete sharing package stays swappable and tests can
/// use a fake with no platform channel.
///
/// Implementations are not required to swallow failures the way
/// [AudioService]/[HapticService] are: a failed share (e.g. no share target
/// available, or a platform-level error) is allowed to throw, so presentation
/// code can distinguish "opened the share sheet" from "sharing failed" and
/// show appropriate feedback for each.
abstract class ResultShareService {
  /// Opens the system share sheet pre-filled with [text], and [subject] when
  /// the chosen share target supports one (e.g. email). Completes once the
  /// share sheet has been dismissed or handed off — not once the user has
  /// necessarily finished sharing, which most platforms don't reliably
  /// report.
  Future<void> shareText({required String text, String? subject});
}

import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Hands an already-rendered share-card PNG to the platform's system share
/// sheet, alongside a short caption.
///
/// A pure platform-invocation abstraction, mirroring `ResultShareService`'s
/// role for plain text: it knows nothing about game rules, card layout, or
/// captions — only how to hand image bytes to the platform. App code depends
/// on this interface rather than on `package:share_plus` directly, so tests
/// can substitute a fake with no platform channel.
abstract class ShareCardService {
  /// Opens the system share sheet with [bytes] (already-encoded PNG data)
  /// attached as [fileName], with [caption] as the accompanying share text.
  /// Completes once the share sheet has been dismissed or handed off — not
  /// once the user has necessarily finished sharing.
  ///
  /// Never writes [bytes] anywhere the caller can observe or must clean up:
  /// the underlying platform implementation is responsible for any
  /// short-lived temporary storage it needs to hand the bytes to the OS
  /// share sheet.
  Future<void> shareImage({
    required Uint8List bytes,
    required String fileName,
    required String caption,
  });
}

/// [ShareCardService] backed by `package:share_plus`.
///
/// Builds the [XFile] straight from in-memory [bytes] via
/// [XFile.fromData] — never writing to app storage itself. [fileNameOverrides]
/// is required alongside it because `cross_file`'s `XFile.fromData` ignores
/// its own `name` parameter on every platform except web (see
/// `share_plus`'s own `Share.shareXFiles` doc); without the override,
/// Android/iOS would fall back to a generated UUID-style filename instead of
/// the descriptive one the milestone calls for. `share_plus`'s platform
/// implementation itself writes these bytes to the OS temporary directory
/// (which it — not this app — is responsible for reclaiming) only to hand
/// the file a real path the native share sheet can read; this class never
/// manages that temporary file itself, and no dependency beyond `share_plus`
/// (already a project dependency) is needed for it.
class SharePlusShareCardService implements ShareCardService {
  const SharePlusShareCardService();

  @override
  Future<void> shareImage({
    required Uint8List bytes,
    required String fileName,
    required String caption,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: [fileName],
        text: caption,
      ),
    );
  }
}

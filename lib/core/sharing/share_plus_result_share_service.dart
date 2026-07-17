import 'package:share_plus/share_plus.dart';

import 'result_share_service.dart';

/// [ResultShareService] backed by `package:share_plus`, wrapping the
/// platform's native share sheet (`ACTION_SEND` on Android,
/// `UIActivityViewController` on iOS). Never targets a specific app (e.g.
/// WhatsApp) directly — the platform's own share sheet always decides which
/// targets are offered.
class SharePlusResultShareService implements ResultShareService {
  const SharePlusResultShareService();

  @override
  Future<void> shareText({required String text, String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}

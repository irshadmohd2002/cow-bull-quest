/// The literal placeholder privacy-policy URL, used until the real,
/// published HTTPS page exists. Kept as its own constant — rather than only
/// inline in [privacyPolicyUrl] — so [isReleaseReadyPrivacyPolicyUrl] can
/// still recognize "the placeholder is still in place" after
/// [privacyPolicyUrl] itself is edited to the app's real value; comparing
/// against [privacyPolicyUrl] directly would be circular and never detect
/// that change.
const String placeholderPrivacyPolicyUrl =
    'https://example.com/cow-bull-quest/privacy';

/// The privacy-policy URL Settings' "Privacy Policy" item opens once it is
/// release-ready (see [isReleaseReadyPrivacyPolicyUrl]). This is the single
/// place the URL is defined — the app must never hard-code it into more
/// than one widget.
///
/// **This is currently [placeholderPrivacyPolicyUrl], not the app's real
/// production URL.** Replace this value with the actual, published HTTPS
/// privacy-policy page (see `docs/play_store/privacy_policy.md`) before
/// release. Until it is replaced, [isReleaseReadyPrivacyPolicyUrl] reports
/// it as not release-ready, which is exactly what keeps the Settings item
/// disabled.
const String privacyPolicyUrl = placeholderPrivacyPolicyUrl;

/// Whether [url] is safe to present as a real, release-ready privacy-policy
/// link: a well-formed HTTPS URL with a non-empty host that is not
/// [placeholderPrivacyPolicyUrl].
///
/// Pure Dart — no `package:flutter` import — so this is unit-testable
/// without a widget tester, and reusable anywhere the app needs to decide
/// whether a candidate URL is ready to show a user rather than a
/// placeholder.
bool isReleaseReadyPrivacyPolicyUrl(String url) {
  if (url == placeholderPrivacyPolicyUrl) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  return true;
}

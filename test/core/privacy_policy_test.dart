import 'package:cowbullgame/core/privacy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('privacyPolicyUrl', () {
    test('is currently the documented placeholder', () {
      expect(privacyPolicyUrl, placeholderPrivacyPolicyUrl);
    });
  });

  group('isReleaseReadyPrivacyPolicyUrl', () {
    test('rejects the placeholder URL', () {
      expect(
        isReleaseReadyPrivacyPolicyUrl(placeholderPrivacyPolicyUrl),
        isFalse,
      );
    });

    test('rejects the current privacyPolicyUrl (still the placeholder)', () {
      expect(isReleaseReadyPrivacyPolicyUrl(privacyPolicyUrl), isFalse);
    });

    test('accepts a well-formed, non-placeholder HTTPS URL', () {
      expect(
        isReleaseReadyPrivacyPolicyUrl('https://cowbullquest.example/privacy'),
        isTrue,
      );
    });

    test('rejects a non-HTTPS scheme', () {
      expect(
        isReleaseReadyPrivacyPolicyUrl('http://cowbullquest.example/privacy'),
        isFalse,
      );
    });

    test('rejects a URL with an empty host', () {
      expect(isReleaseReadyPrivacyPolicyUrl('https:///privacy'), isFalse);
    });

    test('rejects a malformed URL string', () {
      expect(isReleaseReadyPrivacyPolicyUrl('not a url'), isFalse);
    });

    test('rejects an empty string', () {
      expect(isReleaseReadyPrivacyPolicyUrl(''), isFalse);
    });
  });
}

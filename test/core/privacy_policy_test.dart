import 'package:cowbullgame/core/privacy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('privacyPolicyUrl', () {
    test('is the final published URL, not the placeholder', () {
      expect(privacyPolicyUrl, isNot(placeholderPrivacyPolicyUrl));
      expect(
        privacyPolicyUrl,
        'https://irshadmohd2002.github.io/cow-bull-quest/privacy-policy/',
      );
    });
  });

  group('isReleaseReadyPrivacyPolicyUrl', () {
    test('rejects the placeholder URL', () {
      expect(
        isReleaseReadyPrivacyPolicyUrl(placeholderPrivacyPolicyUrl),
        isFalse,
      );
    });

    test('accepts the current privacyPolicyUrl (the final published URL)', () {
      expect(isReleaseReadyPrivacyPolicyUrl(privacyPolicyUrl), isTrue);
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

import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/invite_links.dart';

void main() {
  group('InviteLinks sanitization', () {
    test('cleans basic 6-letter uppercase codes', () {
      expect(InviteLinks.sanitize('KMXPQR'), 'KMXPQR');
    });

    test('normalizes lowercase codes to uppercase', () {
      expect(InviteLinks.sanitize('kmxpqr'), 'KMXPQR');
    });

    test('strips all whitespace (internal, leading, trailing)', () {
      expect(InviteLinks.sanitize('  K M X P Q R  '), 'KMXPQR');
      expect(InviteLinks.sanitize('k m x p q r'), 'KMXPQR');
      expect(InviteLinks.sanitize('AB CD EF'), 'ABCDEF');
      expect(InviteLinks.sanitize('  ABC   DEF  '), 'ABCDEF');
    });

    test('extracts token from standard URL with invite parameter', () {
      expect(
        InviteLinks.sanitize('https://stewardie.web.app/?invite=KMXPQR'),
        'KMXPQR',
      );
      expect(
        InviteLinks.sanitize('https://stewardie.web.app/?invite=kmxpqr'),
        'KMXPQR',
      );
    });

    test('extracts token from URL with token or code parameter', () {
      expect(
        InviteLinks.sanitize('https://stewardie.web.app/?token=KMXPQR'),
        'KMXPQR',
      );
      expect(
        InviteLinks.sanitize('https://stewardie.web.app/?code=kmxpqr'),
        'KMXPQR',
      );
    });

    test('extracts token from hash routing URLs', () {
      expect(
        InviteLinks.sanitize('https://stewardie.web.app/#/join?token=KMXPQR'),
        'KMXPQR',
      );
      expect(
        InviteLinks.sanitize('https://stewardie.web.app/#/join?invite=kmxpqr'),
        'KMXPQR',
      );
    });

    test('extracts token from URL path segments', () {
      expect(
        InviteLinks.sanitize('https://stewardie.web.app/join/KMXPQR'),
        'KMXPQR',
      );
      expect(
        InviteLinks.sanitize('https://stewardie.web.app/#/join/kmxpqr'),
        'KMXPQR',
      );
    });

    test('preserves existing 32-character tokens', () {
      const longToken = 'aB3_k9Xm2LpQ8vBn1234567890abcdef';
      expect(InviteLinks.sanitize(longToken), longToken.toUpperCase());
    });

    test('generates valid web URL from token', () {
      final url = InviteLinks.buildUrl('kmx pqr');
      expect(url.contains('invite=KMXPQR'), isTrue);
    });
  });
}

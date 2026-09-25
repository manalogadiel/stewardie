import 'package:flutter/foundation.dart';

/// Utilities for sanitizing and formatting space invitation codes and URLs.
class InviteLinks {
  const InviteLinks._();

  /// Unambiguous uppercase character set for 6-letter invite codes
  /// (excludes easily confused letters like I and O).
  static const String codeCharset = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// Sanitizes raw user input into a clean, uppercase invite token.
  ///
  /// Handles:
  /// - Full URLs: `https://stewardie.web.app/?invite=KMXPQR`
  /// - Hash URLs: `https://stewardie.web.app/#/join?token=KMXPQR`
  /// - Path URLs: `https://stewardie.web.app/join/KMXPQR`
  /// - Spaced codes: `K M X  P Q R` or `kmx pqr` -> `KMXPQR`
  /// - Case normalization: always returns uppercase.
  static String sanitize(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return '';

    // Check if input is a URI / URL
    if (raw.contains('://') || raw.startsWith('//') || raw.contains('?')) {
      try {
        final uri = Uri.parse(raw);
        // Check query parameters in main URI
        final queryParam = uri.queryParameters['invite'] ??
            uri.queryParameters['token'] ??
            uri.queryParameters['code'];
        if (queryParam != null && queryParam.trim().isNotEmpty) {
          raw = queryParam;
        } else if (uri.fragment.isNotEmpty) {
          // Check fragment query parameters (e.g. #/join?token=...)
          final fragmentIndex = uri.fragment.indexOf('?');
          if (fragmentIndex != -1) {
            final fragmentQuery = Uri.splitQueryString(
              uri.fragment.substring(fragmentIndex + 1),
            );
            final fragParam = fragmentQuery['invite'] ??
                fragmentQuery['token'] ??
                fragmentQuery['code'];
            if (fragParam != null && fragParam.trim().isNotEmpty) {
              raw = fragParam;
            }
          } else {
            // Check path within fragment, e.g. #/join/KMXPQR
            final segments = uri.fragment
                .split('/')
                .where((s) => s.isNotEmpty)
                .toList();
            if (segments.isNotEmpty && segments.last.length >= 6) {
              raw = segments.last;
            }
          }
        } else if (uri.pathSegments.isNotEmpty) {
          // Check standard path segment, e.g. /join/KMXPQR
          final last = uri.pathSegments.last;
          if (last.length >= 6) {
            raw = last;
          }
        }
      } catch (_) {
        // Fallback to raw string if URI parsing fails
      }
    }

    // Strip all whitespace (including internal spaces, tabs, newlines) and uppercase
    return raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  /// Builds a shareable web invitation URL for the given [token].
  static String buildUrl(String token) {
    final cleanToken = sanitize(token);
    if (kIsWeb) {
      final base = Uri.base;
      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        queryParameters: {'invite': cleanToken},
      ).toString();
    }
    return 'https://stewardie.web.app/?invite=$cleanToken';
  }
}

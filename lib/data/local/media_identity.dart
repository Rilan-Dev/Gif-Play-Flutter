import 'dart:convert';
import 'package:crypto/crypto.dart';

class MediaIdentity {
  const MediaIdentity._();

  static String fromUrls({
    required String mediaUrl,
    String? sourceUrl,
    String? sourceName,
  }) {
    final canonicalMedia = canonicalizeUrl(mediaUrl);
    final canonicalSource = sourceUrl == null ? '' : canonicalizeUrl(sourceUrl);
    final source = (sourceName ?? '').trim().toLowerCase();
    return sha256.convert(
      utf8.encode('$source|$canonicalSource|$canonicalMedia'),
    ).toString();
  }

  static String canonicalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return trimmed;

    final query = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((key, _) {
        final k = key.toLowerCase();
        return k.startsWith('utm_') || k == 'fbclid' || k == 'gclid' || k == 'ref';
      });
    final sorted = query.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      queryParameters: Map.fromEntries(sorted),
      fragment: '',
    ).toString();
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

import '../../common/models/gif_item.dart';
import '../../common/models/media_item.dart';
import '../../common/utils/shared_preferences_util.dart';

/// Service class for handling data fetching and processing for the MoodVibe screen
class MoodVibeDataService {
  /// Fetches GIF data from a URL
  static Future<Map<String, dynamic>> fetchGifData(String gifLink) async {
    final Map<String, dynamic> result = {
      'gifItems': <GifItem>[],
      'mediaItems': <MediaItem>[],
      'suggestedItems': <MediaItem>[],
      'hasError': false,
      'errorMessage': '',
    };

    try {
      final response = await http.get(
        Uri.parse(gifLink),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // Parse main GIFs
        final imageElements =
            document.querySelectorAll('.single-main .single-image img');

        if (imageElements.isEmpty) {
          debugPrint('No image elements found');
          result['hasError'] = true;
          result['errorMessage'] = 'No GIFs found on this page';
          return result;
        }

        for (var imageElement in imageElements) {
          try {
            final imageUrl = imageElement.attributes['src'] ?? '';
            final altText = imageElement.attributes['alt'] ?? '';
            final width =
                int.tryParse(imageElement.attributes['width'] ?? '0') ?? 0;
            final height =
                int.tryParse(imageElement.attributes['height'] ?? '0') ?? 0;

            if (imageUrl.isNotEmpty) {
              final gifItem = GifItem(
                id: DateTime.now().millisecondsSinceEpoch.toString() +
                    imageUrl.hashCode.toString(),
                url: imageUrl,
                title: altText,
                imageUrl: imageUrl,
                altText: altText,
                width: width,
                height: height,
              );

              final mediaItem = MediaItem(
                imageUrl: imageUrl,
                title: altText,
                href: imageUrl,
                timestamp: DateTime.now(),
              );

              result['gifItems'].add(gifItem);
              result['mediaItems'].add(mediaItem);
            }
          } catch (e) {
            debugPrint('Error parsing image element: $e');
            continue;
          }
        }

        // Parse suggested thumbnails from section.page
        final suggestedSections = document.querySelectorAll('section.page');

        // Look for the section with thumbnails (usually the last one)
        if (suggestedSections.isNotEmpty) {
          // Find the section with thumb-loop elements (usually the last one)
          for (var section in suggestedSections) {
            final thumbnails = section.querySelectorAll('.thumb.thumb-loop');
            if (thumbnails.isNotEmpty) {
              for (var thumbnail in thumbnails) {
                try {
                  final thumbImageElement =
                      thumbnail.querySelector('.thumb-image a');
                  final imgElement =
                      thumbnail.querySelector('.thumb-image a img');

                  if (thumbImageElement != null && imgElement != null) {
                    final href = thumbImageElement.attributes['href'] ?? '';
                    final title = thumbImageElement.attributes['title'] ??
                        imgElement.attributes['alt'] ??
                        'No Title';
                    final imageUrl = imgElement.attributes['src'] ?? '';

                    if (imageUrl.isNotEmpty && href.isNotEmpty) {
                      final mediaItem = MediaItem(
                        imageUrl: imageUrl,
                        title: title,
                        href: href,
                        timestamp: DateTime.now(),
                      );

                      result['suggestedItems'].add(mediaItem);
                    }
                  }
                } catch (e) {
                  debugPrint('Error parsing suggested thumbnail: $e');
                  continue;
                }
              }
              // Break after finding the first section with thumbnails
              break;
            }
          }
        }

        // Store the viewed GIF
        try {
          await SharedPreferencesUtil.storeContact(
            gifLink,
            gifLink,
          );
        } catch (e) {
          debugPrint('Error storing contact: $e');
        }
      } else {
        result['hasError'] = true;
        result['errorMessage'] = 'HTTP error: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      result['hasError'] = true;
      result['errorMessage'] = 'Error: $e';
    }

    return result;
  }

  /// Fetches GIFs from a specific URL
  static Future<List<GifItem>> fetchGifsFromUrl(String url) async {
    final List<GifItem> gifs = [];

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final imageElements =
            document.querySelectorAll('.single-main .single-image img');

        for (var imageElement in imageElements) {
          try {
            final imageUrl = imageElement.attributes['src'] ?? '';
            final altText = imageElement.attributes['alt'] ?? '';
            final width =
                int.tryParse(imageElement.attributes['width'] ?? '0') ?? 0;
            final height =
                int.tryParse(imageElement.attributes['height'] ?? '0') ?? 0;

            if (imageUrl.isNotEmpty) {
              gifs.add(GifItem(
                id: DateTime.now().millisecondsSinceEpoch.toString() +
                    imageUrl.hashCode.toString(),
                url: imageUrl,
                title: altText,
                imageUrl: imageUrl,
                altText: altText,
                width: width,
                height: height,
              ));
            }
          } catch (e) {
            debugPrint('Error parsing image element: $e');
            continue;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching GIFs: $e');
    }

    return gifs;
  }

  /// Formats a timestamp into a human-readable string
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}


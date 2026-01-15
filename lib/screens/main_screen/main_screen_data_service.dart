import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:math';

import '../../common/models/media_item.dart';
import '../../common/models/gif_item.dart';

/// Service class for handling data operations in the main screen
class MainScreenDataService {
  /// Fetches GIF data from the web
  static Future<Map<String, dynamic>> fetchData({
    required int currentPage,
    required List<MediaItem> mediaItems,
    required List<MediaItem> filteredItems,
    required TextEditingController searchController,
    required Set<int>? visitedPages,
    required int totalPages,
  }) async {
    final Map<String, dynamic> result = {
      'mediaItems': List<MediaItem>.from(mediaItems),
      'filteredItems': List<MediaItem>.from(filteredItems),
      'hasError': false,
      'errorMessage': '',
      'visitedPages': visitedPages ?? <int>{},
      'totalPages': totalPages,
    };

    try {
      // Initialize the set of visited pages if it doesn't exist
      if (result['visitedPages'] == null) {
        result['visitedPages'] = <int>{};
      }

      // Determine which page to fetch
      int pageToFetch;
      
      // If we've visited all available pages or don't know total pages yet, reset
      if (result['visitedPages'].length >= result['totalPages'] && result['totalPages'] > 0) {
        result['visitedPages'].clear();
      }
      
      // If we don't know total pages yet, use a default range (1-50)
      if (result['totalPages'] <= 0) {
        // Keep trying to find an unvisited page
        do {
          pageToFetch = Random().nextInt(50) + 1; // Random page between 1 and 50
        } while (result['visitedPages'].contains(pageToFetch) && result['visitedPages'].length < 50);
      } else {
        // We know total pages, pick a random unvisited page
        do {
          pageToFetch = Random().nextInt(result['totalPages']) + 1; // Random page between 1 and total pages
        } while (result['visitedPages'].contains(pageToFetch) && result['visitedPages'].length < result['totalPages']);
      }
      
      // Mark this page as visited
      result['visitedPages'].add(pageToFetch);
      
      debugPrint('Fetching random page: $pageToFetch (visited: ${result['visitedPages'].length} pages)');

      // Fetch the selected page
      final response = await http.get(
        Uri.parse('https://porngifmag.com/page/$pageToFetch'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      );
    
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        // Try to get total pages if not already fetched
        if (result['totalPages'] == 0) {
          try {
            final paginationElements = document.querySelectorAll('.pagination a');
            int highestPage = 1;
            
            for (var element in paginationElements) {
              final pageText = element.text.trim();
              final pageNum = int.tryParse(pageText);
              if (pageNum != null && pageNum > highestPage) {
                highestPage = pageNum;
              }
            }
            
            result['totalPages'] = highestPage > 1 ? highestPage : 50; // Default to 50 if can't determine
            debugPrint('Detected total pages: ${result['totalPages']}');
          } catch (e) {
            debugPrint('Error parsing pagination: $e');
            result['totalPages'] = 50; // Default to 50 pages
          }
        }
        
        // Parse articles
        try {
          final articleElements = document.querySelectorAll('.thumb.thumb-loop');
          
          if (articleElements.isEmpty) {
            debugPrint('No article elements found on page $pageToFetch');
          }
          
          for (var article in articleElements) {
            try {
              final imageElement = article.querySelector('.thumb-image img');
              final linkElement = article.querySelector('a');
              
              if (imageElement != null && linkElement != null) {
                final href = linkElement.attributes['href'] ?? '';
                final title = imageElement.attributes['alt'] ?? '';
                final imageUrl = imageElement.attributes['src'] ?? '';
                
                if (imageUrl.isNotEmpty && href.isNotEmpty) {
                  final mediaItem = MediaItem(
                    imageUrl: imageUrl,
                    title: title,
                    href: href,
                  );
                  
                  result['mediaItems'].add(mediaItem);
                  if (searchController.text.isEmpty) {
                    result['filteredItems'].add(mediaItem);
                  } else if (title.toLowerCase().contains(searchController.text.toLowerCase())) {
                    result['filteredItems'].add(mediaItem);
                  }
                }
              }
            } catch (e) {
              debugPrint('Error parsing article: $e');
              continue; // Skip this article and continue with the next
            }
          }
          
        } catch (e) {
          debugPrint('Error parsing articles: $e');
          result['hasError'] = true;
          result['errorMessage'] = 'Error parsing articles: $e';
        }
      } else {
        debugPrint('HTTP error: ${response.statusCode}');
        result['hasError'] = true;
        result['errorMessage'] = 'HTTP error: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      result['hasError'] = true;
      result['errorMessage'] = 'Error fetching data: $e';
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
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      );
      
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final imageElements = document.querySelectorAll('.single-main .single-image img');
        
        for (var imageElement in imageElements) {
          try {
            final imageUrl = imageElement.attributes['src'] ?? '';
            final altText = imageElement.attributes['alt'] ?? '';
            final width = int.tryParse(imageElement.attributes['width'] ?? '0') ?? 0;
            final height = int.tryParse(imageElement.attributes['height'] ?? '0') ?? 0;
            
            if (imageUrl.isNotEmpty) {
              gifs.add(GifItem(
                id: DateTime.now().millisecondsSinceEpoch.toString() + imageUrl.hashCode.toString(),
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
}


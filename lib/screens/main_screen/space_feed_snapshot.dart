import 'dart:convert';

import '../../common/models/media_item.dart';

/// Parsed, bounded feed state for a single persistent browsing Space.
class SpaceFeedSnapshot {
  const SpaceFeedSnapshot({
    required this.mediaItems,
    required this.currentPage,
    required this.totalPages,
    required this.visitedPages,
    required this.searchQuery,
    required this.scrollOffset,
  });

  final List<MediaItem> mediaItems;
  final int currentPage;
  final int totalPages;
  final Set<int> visitedPages;
  final String searchQuery;
  final double scrollOffset;

  /// Empty, malformed, or unavailable snapshots should recover from the feed
  /// source instead of leaving a Space permanently blank.
  bool get requiresFetch => mediaItems.isEmpty;

  factory SpaceFeedSnapshot.restore({
    String? feedStateJson,
    String? persistedSearchQuery,
    double? persistedScrollOffset,
    int? persistedPage,
  }) {
    Map<String, dynamic>? decoded;
    if (feedStateJson != null && feedStateJson.isNotEmpty) {
      try {
        final value = jsonDecode(feedStateJson);
        if (value is Map<String, dynamic>) decoded = value;
      } catch (_) {
        // A malformed optional snapshot is recoverable: return an empty state
        // and let the caller perform a fresh feed fetch.
      }
    }

    final items = (decoded?['mediaItems'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => MediaItem.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.imageUrl.isNotEmpty)
        .take(120)
        .toList(growable: false);
    final query = persistedSearchQuery ??
        (decoded?['searchQuery'] as String? ?? '');
    final visited = (decoded?['visitedPages'] as List<dynamic>?)
            ?.whereType<num>()
            .map((value) => value.toInt())
            .toSet() ??
        <int>{};

    return SpaceFeedSnapshot(
      mediaItems: items,
      currentPage: (decoded?['currentPage'] as num?)?.toInt() ??
          persistedPage ??
          1,
      totalPages: (decoded?['totalPages'] as num?)?.toInt() ?? 0,
      visitedPages: visited,
      searchQuery: query,
      scrollOffset: persistedScrollOffset ??
          (decoded?['scrollOffset'] as num?)?.toDouble() ??
          0,
    );
  }
}

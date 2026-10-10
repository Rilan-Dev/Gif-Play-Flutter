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

    final rawItems = decoded?['mediaItems'];
    final items = (rawItems is List ? rawItems : const <dynamic>[])
        .whereType<Map>()
        .map((item) => MediaItem.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.imageUrl.isNotEmpty)
        .take(120)
        .toList(growable: false);
    final rawQuery = decoded?['searchQuery'];
    final query = persistedSearchQuery ??
        (rawQuery is String ? rawQuery : '');
    final rawVisited = decoded?['visitedPages'];
    final visited = rawVisited is List
        ? rawVisited.whereType<num>().map((value) => value.toInt()).toSet()
        : <int>{};
    final rawCurrentPage = decoded?['currentPage'];
    final rawTotalPages = decoded?['totalPages'];
    final rawScrollOffset = decoded?['scrollOffset'];

    return SpaceFeedSnapshot(
      mediaItems: items,
      currentPage: rawCurrentPage is num
          ? rawCurrentPage.toInt()
          : (persistedPage ?? 1),
      totalPages: rawTotalPages is num ? rawTotalPages.toInt() : 0,
      visitedPages: visited,
      searchQuery: query,
      scrollOffset: persistedScrollOffset ??
          (rawScrollOffset is num ? rawScrollOffset.toDouble() : 0),
    );
  }
}

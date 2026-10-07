class DetailTab {
  const DetailTab({
    required this.id,
    required this.spaceId,
    required this.openedAt,
    required this.updatedAt,
    required this.lastAccessedAt,
    this.mediaId,
    this.canonicalUrl,
    this.title,
    this.thumbnailUrl,
    this.scrollOffset,
    this.stateJson,
    this.sortOrder = 0,
    this.isClosed = false,
  });

  final String id;
  final String spaceId;
  final String? mediaId;
  final String? canonicalUrl;
  final String? title;
  final String? thumbnailUrl;
  final DateTime openedAt;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;
  final double? scrollOffset;
  final String? stateJson;
  final int sortOrder;
  final bool isClosed;
}

class MediaRecord {
  const MediaRecord({
    required this.id,
    required this.sourceUrl,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.title,
    this.sourceName,
    this.width,
    this.height,
    this.mimeType,
    this.tagsText,
    this.searchText = '',
    this.createdAt,
    this.updatedAt,
    this.lastViewedAt,
    this.lastSeenAt,
    this.schemaVersion = 1,
  });
  final String id;
  final String sourceUrl;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String? title;
  final String? sourceName;
  final int? width;
  final int? height;
  final String? mimeType;
  final String? tagsText;
  final String searchText;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastViewedAt;
  final DateTime? lastSeenAt;
  final int schemaVersion;
}

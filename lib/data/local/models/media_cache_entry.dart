enum MediaCacheStatus { downloading, ready, failed, expired }

class MediaCacheEntry {
  const MediaCacheEntry({
    required this.mediaId,
    required this.localPath,
    required this.byteSize,
    required this.downloadedAt,
    required this.lastAccessedAt,
    required this.status,
    this.expiresAt,
    this.checksum,
    this.failureCount = 0,
    this.lastError,
  });
  final String mediaId;
  final String localPath;
  final int byteSize;
  final DateTime downloadedAt;
  final DateTime lastAccessedAt;
  final DateTime? expiresAt;
  final String? checksum;
  final MediaCacheStatus status;
  final int failureCount;
  final String? lastError;
}

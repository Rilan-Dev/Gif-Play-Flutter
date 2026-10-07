enum CollectionShareState { pending, sharing, shared, failed }
enum CollectionCacheState { notCached, downloading, ready, failed, expired }

class CollectionItem {
  const CollectionItem({
    required this.collectionId,
    required this.mediaId,
    required this.position,
    required this.addedAt,
    this.shareState = CollectionShareState.pending,
    this.cacheState = CollectionCacheState.notCached,
    this.sharedAt,
    this.lastError,
  });
  final String collectionId;
  final String mediaId;
  final int position;
  final DateTime addedAt;
  final CollectionShareState shareState;
  final CollectionCacheState cacheState;
  final DateTime? sharedAt;
  final String? lastError;
}

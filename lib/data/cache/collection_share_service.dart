import '../local/local_media_repository.dart';
import '../local/models/media_record.dart';
import 'media_cache_manager.dart';

class CollectionSharePreparation {
  const CollectionSharePreparation({
    required this.collectionId,
    required this.media,
    required this.cachedFiles,
    required this.readiness,
  });

  final String collectionId;
  final List<MediaRecord> media;
  final List<CachePreparationResult> cachedFiles;
  final CollectionCacheReadiness readiness;

  bool get isReadyToShare =>
      readiness.pending > 0 &&
      cachedFiles.length >= readiness.pending &&
      readiness.failed == 0;
}

class CollectionShareService {
  CollectionShareService(
    this.repository, {
    MediaCacheManager? cacheManager,
  }) : cacheManager = cacheManager ?? MediaCacheManager(repository);

  final LocalMediaRepository repository;
  final MediaCacheManager cacheManager;

  Future<CollectionSharePreparation> prepareCollection(
    String collectionId, {
    int limit = 500,
  }) async {
    final media = await repository.listCollectionMedia(
      collectionId,
      pendingOnly: true,
      limit: limit,
    );
    final cachedFiles = await cacheManager.prepareCollection(
      collectionId,
      limit: limit,
    );
    final readiness = await cacheManager.getCollectionReadiness(
      collectionId,
    );

    return CollectionSharePreparation(
      collectionId: collectionId,
      media: media,
      cachedFiles: cachedFiles,
      readiness: readiness,
    );
  }

  Future<List<CollectionSharePreparation>> prepareCollections(
    Iterable<String> collectionIds, {
    int limitPerCollection = 500,
  }) async {
    final preparations = <CollectionSharePreparation>[];
    for (final collectionId in collectionIds.toSet()) {
      preparations.add(
        await prepareCollection(
          collectionId,
          limit: limitPerCollection,
        ),
      );
    }
    return preparations;
  }

  Future<void> markCollectionsShared(
    Iterable<CollectionSharePreparation> preparations,
  ) async {
    for (final preparation in preparations) {
      if (!preparation.isReadyToShare) continue;
      final mediaIds = preparation.cachedFiles.map((result) => result.mediaId);
      await repository.markCollectionItemsShared(
        preparation.collectionId,
        mediaIds,
      );
    }
  }
}

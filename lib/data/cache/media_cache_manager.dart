import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../common/utils/file_utils.dart';
import '../local/local_media_repository.dart';
import '../local/models/collection_item.dart';
import '../local/models/media_cache_entry.dart';
import '../local/models/media_record.dart';

class CachePreparationResult {
  const CachePreparationResult({
    required this.mediaId,
    required this.file,
    required this.fromCache,
  });

  final String mediaId;
  final File file;
  final bool fromCache;
}

class CollectionCacheReadiness {
  const CollectionCacheReadiness({
    required this.total,
    required this.pending,
    required this.ready,
    required this.downloading,
    required this.notCached,
    required this.failed,
    required this.expired,
  });

  final int total;
  final int pending;
  final int ready;
  final int downloading;
  final int notCached;
  final int failed;
  final int expired;

  bool get isReadyToShare => pending > 0 && ready >= pending;
}

class CacheMaintenanceResult {
  const CacheMaintenanceResult({
    required this.removedEntries,
    required this.removedBytes,
    required this.remainingBytes,
  });

  final int removedEntries;
  final int removedBytes;
  final int remainingBytes;
}

class MediaCacheManager {
  MediaCacheManager(
    this.repository, {
    this.maxBytes = 200 * 1024 * 1024,
    this.maxConcurrentDownloads = 3,
    this.entryTtl = const Duration(days: 30),
    this.maxRetries = 2,
    this.retryBaseDelay = const Duration(milliseconds: 500),
    http.Client? client,
  }) : client = client ?? http.Client();

  final LocalMediaRepository repository;
  final int maxBytes;
  final int maxConcurrentDownloads;
  final Duration entryTtl;
  final int maxRetries;
  final Duration retryBaseDelay;
  final http.Client client;

  /// Produces a filesystem-safe, deterministic cache filename.
  static String cacheFileNameForMediaId(String mediaId) =>
      sha256.convert(utf8.encode(mediaId)).toString();

  Future<CachePreparationResult?> prepareMedia(
    MediaRecord media, {
    String? collectionId,
  }) async {
    // Queue-originated GIFs may not yet exist in media_records. Cache entries
    // reference that table with a foreign key, so persist the canonical media
    // record before reading or creating its cache entry.
    await repository.upsertMedia(media);
    final now = DateTime.now();
    final existing = await repository.getCacheEntry(media.id);

    if (existing != null && existing.status == MediaCacheStatus.ready) {
      final file = File(existing.localPath);
      final expired =
          existing.expiresAt != null && existing.expiresAt!.isBefore(now);

      if (!expired && await file.exists()) {
        await repository.touchCacheEntry(media.id, accessedAt: now);
        if (collectionId != null) {
          await repository.updateCollectionItemCacheState(
            collectionId: collectionId,
            mediaId: media.id,
            cacheState: CollectionCacheState.ready,
          );
        }
        return CachePreparationResult(
          mediaId: media.id,
          file: file,
          fromCache: true,
        );
      }

      if (collectionId != null) {
        await repository.updateCollectionItemCacheState(
          collectionId: collectionId,
          mediaId: media.id,
          cacheState: CollectionCacheState.expired,
          error: 'Cached file is missing or expired',
        );
      }
      await _removeEntryAndFile(existing);
    }

    if (collectionId != null) {
      await repository.updateCollectionItemCacheState(
        collectionId: collectionId,
        mediaId: media.id,
        cacheState: CollectionCacheState.downloading,
      );
    }

    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final multiplier = 1 << (attempt - 1);
          await Future<void>.delayed(retryBaseDelay * multiplier);
        }

        final result = await _downloadOnce(media);
        if (collectionId != null) {
          await repository.updateCollectionItemCacheState(
            collectionId: collectionId,
            mediaId: media.id,
            cacheState: CollectionCacheState.ready,
          );
        }
        await evictIfNeeded(preserveMediaIds: {media.id});
        return result;
      } catch (error) {
        lastError = error;
      }
    }

    final failure = lastError?.toString() ?? 'Unknown cache preparation error';
    await repository.upsertCacheEntry(MediaCacheEntry(
      mediaId: media.id,
      localPath: '',
      byteSize: 0,
      downloadedAt: now,
      lastAccessedAt: now,
      status: MediaCacheStatus.failed,
      failureCount: (existing?.failureCount ?? 0) + maxRetries + 1,
      lastError: failure,
    ));
    if (collectionId != null) {
      await repository.updateCollectionItemCacheState(
        collectionId: collectionId,
        mediaId: media.id,
        cacheState: CollectionCacheState.failed,
        error: failure,
      );
    }
    return null;
  }

  Future<CachePreparationResult> _downloadOnce(MediaRecord media) async {
    final url = media.mediaUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Media URL is not an HTTP(S) URL');
    }

    final response = await client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const FormatException('Downloaded media is empty');
    }

    final folder = await FileUtils.getHiddenFolder();
    final cacheFolder = Directory('${folder.path}/gif_cache');
    if (!await cacheFolder.exists()) {
      await cacheFolder.create(recursive: true);
    }

    // IDs can originate from older callers or imported queues and may
    // contain URL path separators. Never interpolate them into filesystem paths.
    final safeFileName = cacheFileNameForMediaId(media.id);
    final finalFile = File('${cacheFolder.path}/$safeFileName.bin');
    final tempFile = File('${finalFile.path}.part');
    await tempFile.writeAsBytes(bytes, flush: true);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await tempFile.rename(finalFile.path);

    final timestamp = DateTime.now();
    await repository.upsertCacheEntry(MediaCacheEntry(
      mediaId: media.id,
      localPath: finalFile.path,
      byteSize: bytes.length,
      downloadedAt: timestamp,
      lastAccessedAt: timestamp,
      expiresAt: timestamp.add(entryTtl),
      checksum: sha256.convert(bytes).toString(),
      status: MediaCacheStatus.ready,
    ));

    return CachePreparationResult(
      mediaId: media.id,
      file: finalFile,
      fromCache: false,
    );
  }

  Future<CollectionCacheReadiness> getCollectionReadiness(
    String collectionId, {
    bool pendingOnly = true,
  }) async {
    final items = await repository.listCollectionItems(
      collectionId,
      pendingOnly: pendingOnly,
      limit: 5000,
    );

    var ready = 0;
    var downloading = 0;
    var notCached = 0;
    var failed = 0;
    var expired = 0;

    for (final item in items) {
      switch (item.cacheState) {
        case CollectionCacheState.ready:
          ready++;
        case CollectionCacheState.downloading:
          downloading++;
        case CollectionCacheState.notCached:
          notCached++;
        case CollectionCacheState.failed:
          failed++;
        case CollectionCacheState.expired:
          expired++;
      }
    }

    return CollectionCacheReadiness(
      total: items.length,
      pending: items
          .where((item) => item.shareState == CollectionShareState.pending)
          .length,
      ready: ready,
      downloading: downloading,
      notCached: notCached,
      failed: failed,
      expired: expired,
    );
  }

  Future<List<CachePreparationResult>> prepareCollection(
    String collectionId, {
    int limit = 500,
  }) async {
    final items = await repository.listCollectionItems(
      collectionId,
      pendingOnly: true,
      limit: limit,
    );
    final results = <CachePreparationResult>[];
    var cursor = 0;
    final workerCount = items.isEmpty
        ? 0
        : (maxConcurrentDownloads < items.length
            ? maxConcurrentDownloads
            : items.length);

    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= items.length) return;
        final item = items[index];
        final media = await repository.getMedia(item.mediaId);
        if (media == null) continue;
        final result =
            await prepareMedia(media, collectionId: collectionId);
        if (result != null) results.add(result);
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }

  Future<void> evictIfNeeded({
    Set<String> preserveMediaIds = const {},
  }) async {
    var total = await repository.countCacheBytes();
    if (total <= maxBytes) return;

    final entries = await repository.listCacheEntries();
    for (final entry in entries) {
      if (total <= maxBytes) break;
      if (preserveMediaIds.contains(entry.mediaId)) continue;

      final size = entry.byteSize;
      await _removeEntryAndFile(entry);
      total -= size;
    }
  }

  Future<CacheMaintenanceResult> cleanup({
    bool removeExpired = true,
    bool removeFailed = true,
  }) async {
    var removedEntries = 0;
    var removedBytes = 0;
    final now = DateTime.now();

    for (final entry in await repository.listCacheEntries()) {
      final expired = entry.expiresAt != null && entry.expiresAt!.isBefore(now);
      final shouldRemove = (removeExpired && expired) ||
          (removeFailed && entry.status == MediaCacheStatus.failed);
      if (!shouldRemove) continue;

      removedBytes += entry.byteSize;
      removedEntries++;
      await _removeEntryAndFile(entry);
    }

    await evictIfNeeded();
    return CacheMaintenanceResult(
      removedEntries: removedEntries,
      removedBytes: removedBytes,
      remainingBytes: await repository.countCacheBytes(),
    );
  }

  Future<void> _removeEntryAndFile(MediaCacheEntry entry) async {
    if (entry.localPath.isNotEmpty) {
      final file = File(entry.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await repository.deleteCacheEntry(entry.mediaId);
  }
}

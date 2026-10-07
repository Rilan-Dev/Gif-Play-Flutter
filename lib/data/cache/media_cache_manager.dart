import 'dart:io';
import 'dart:typed_data';

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

class MediaCacheManager {
  MediaCacheManager(
    this.repository, {
    this.maxBytes = 200 * 1024 * 1024,
    this.maxConcurrentDownloads = 3,
    this.entryTtl = const Duration(days: 30),
  });

  final LocalMediaRepository repository;
  final int maxBytes;
  final int maxConcurrentDownloads;
  final Duration entryTtl;

  Future<CachePreparationResult?> prepareMedia(
    MediaRecord media, {
    String? collectionId,
  }) async {
    final now = DateTime.now();
    final existing = await repository.getCacheEntry(media.id);
    if (existing != null && existing.status == MediaCacheStatus.ready) {
      final file = File(existing.localPath);
      final expired = existing.expiresAt != null && existing.expiresAt!.isBefore(now);
      if (!expired && await file.exists()) {
        await repository.touchCacheEntry(media.id, accessedAt: now);
        if (collectionId != null) {
          await repository.updateCollectionItemCacheState(
            collectionId: collectionId,
            mediaId: media.id,
            cacheState: CollectionCacheState.ready,
          );
        }
        return CachePreparationResult(mediaId: media.id, file: file, fromCache: true);
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

    try {
      final url = media.mediaUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        throw const FormatException('Media URL is not an HTTP(S) URL');
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) throw const FormatException('Downloaded media is empty');

      final folder = await FileUtils.getHiddenFolder();
      final cacheFolder = Directory('${folder.path}/gif_cache');
      if (!await cacheFolder.exists()) await cacheFolder.create(recursive: true);
      final finalFile = File('${cacheFolder.path}/${media.id}.bin');
      final tempFile = File('${finalFile.path}.part');
      await tempFile.writeAsBytes(bytes, flush: true);
      if (await finalFile.exists()) await finalFile.delete();
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
      if (collectionId != null) {
        await repository.updateCollectionItemCacheState(
          collectionId: collectionId,
          mediaId: media.id,
          cacheState: CollectionCacheState.ready,
        );
      }
      await evictIfNeeded(preserveMediaIds: {media.id});
      return CachePreparationResult(mediaId: media.id, file: finalFile, fromCache: false);
    } catch (error) {
      await repository.upsertCacheEntry(MediaCacheEntry(
        mediaId: media.id,
        localPath: '',
        byteSize: 0,
        downloadedAt: now,
        lastAccessedAt: now,
        status: MediaCacheStatus.failed,
        failureCount: (existing?.failureCount ?? 0) + 1,
        lastError: error.toString(),
      ));
      if (collectionId != null) {
        await repository.updateCollectionItemCacheState(
          collectionId: collectionId,
          mediaId: media.id,
          cacheState: CollectionCacheState.failed,
          error: error.toString(),
        );
      }
      return null;
    }
  }

  Future<List<CachePreparationResult>> prepareCollection(
    String collectionId, {
    int limit = 500,
  }) async {
    final items = await repository.listCollectionItems(collectionId, pendingOnly: true, limit: limit);
    final results = <CachePreparationResult>[];
    var cursor = 0;
    final workerCount = items.isEmpty ? 0 : (maxConcurrentDownloads < items.length ? maxConcurrentDownloads : items.length);
    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= items.length) return;
        final item = items[index];
        final media = await repository.getMedia(item.mediaId);
        if (media == null) continue;
        final result = await prepareMedia(media, collectionId: collectionId);
        if (result != null) results.add(result);
      }
    }
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }

  Future<void> evictIfNeeded({Set<String> preserveMediaIds = const {}}) async {
    var total = await repository.countCacheBytes();
    if (total <= maxBytes) return;
    final entries = await repository.listCacheEntries();
    for (final entry in entries) {
      if (total <= maxBytes) break;
      if (preserveMediaIds.contains(entry.mediaId)) continue;
      if (entry.status != MediaCacheStatus.ready) {
        await _removeEntryAndFile(entry);
        continue;
      }
      final size = entry.byteSize;
      await _removeEntryAndFile(entry);
      total -= size;
    }
  }

  Future<void> _removeEntryAndFile(MediaCacheEntry entry) async {
    if (entry.localPath.isNotEmpty) {
      final file = File(entry.localPath);
      if (await file.exists()) await file.delete();
    }
    await repository.deleteCacheEntry(entry.mediaId);
  }
}
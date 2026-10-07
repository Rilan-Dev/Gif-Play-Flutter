import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/cache/collection_share_service.dart';
import '../../data/cache/media_cache_manager.dart';
import '../../data/local/media_identity.dart';
import '../../data/local/models/media_record.dart';
import '../models/gif_item.dart';
import 'file_utils.dart';

/// Utility class for preparing, downloading, and sharing media.
///
/// Remote media always uses the canonical MediaCacheManager path. Local files
/// already produced by the app can be shared directly without a second
/// download or cache entry.
class DownloadAndShare {
  Future<void> downloadAndShareGifs(
    BuildContext context,
    List<GifItem> gifs,
    bool share,
  ) async {
    if (gifs.isEmpty) {
      _showMessage(context, 'No GIFs selected', backgroundColor: Colors.orange);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Text(
              share
                  ? 'Preparing ${gifs.length > 1 ? '${gifs.length} GIFs' : 'GIF'} to share...'
                  : 'Downloading ${gifs.length > 1 ? '${gifs.length} GIFs' : 'GIF'}...',
            ),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final cacheManager = _cacheManagerOrNull(context);
      if (cacheManager == null) {
        throw StateError(
          'MediaCacheManager is not configured; refusing to use a duplicate download path.',
        );
      }

      final files = <File>[];
      final failures = <String>[];

      for (final gif in gifs) {
        final localFile = await _existingLocalFile(gif);
        if (localFile != null) {
          files.add(localFile);
          if (!share) await FileUtils.saveFile(localFile);
          continue;
        }

        final mediaUrl = (gif.imageUrl ?? gif.url ?? '').trim();
        if (mediaUrl.isEmpty || !mediaUrl.startsWith(RegExp(r'https?://'))) {
          failures.add(gif.title);
          continue;
        }

        final cached = await cacheManager.prepareMedia(_toMediaRecord(gif));
        if (cached == null) {
          failures.add(gif.title);
          continue;
        }

        files.add(cached.file);
        if (!share) await FileUtils.saveFile(cached.file);
      }

      messenger.hideCurrentSnackBar();

      if (share && files.isNotEmpty) {
        await Share.shareXFiles(
          files.map((file) => XFile(file.path)).toList(),
          text: '',
        );
      }

      if (files.isEmpty) {
        _showMessage(
          context,
          failures.isEmpty
              ? 'No GIFs were processed'
              : 'Could not prepare the selected GIFs',
          backgroundColor: Colors.orange,
        );
        return;
      }

      if (!share) {
        _showMessage(
          context,
          '${files.length > 1 ? '${files.length} GIFs' : 'GIF'} saved successfully',
        );
      } else if (failures.isNotEmpty) {
        _showMessage(
          context,
          '${failures.length} GIF${failures.length == 1 ? '' : 's'} could not be prepared',
          backgroundColor: Colors.orange,
        );
      }
    } catch (error) {
      messenger.hideCurrentSnackBar();
      _showMessage(context, 'Error: ${error.toString()}', backgroundColor: Colors.red);
    }
  }

  /// Prepares reusable collections through CollectionShareService and shares
  /// their canonical cached files. Collection metadata is never deleted.
  Future<void> shareCollections(
    BuildContext context,
    Iterable<String> collectionIds,
  ) async {
    final ids = collectionIds.toSet();
    if (ids.isEmpty) {
      _showMessage(context, 'No collections selected', backgroundColor: Colors.orange);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Preparing ${ids.length} collection${ids.length == 1 ? '' : 's'} to share...',
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final service = _collectionShareServiceOrNull(context);
      if (service == null) {
        throw StateError('CollectionShareService is not configured.');
      }

      final preparations = await service.prepareCollections(ids);
      final allReady = preparations.length == ids.length &&
          preparations.every((preparation) => preparation.isReadyToShare);

      if (!allReady) {
        messenger.hideCurrentSnackBar();
        _showMessage(
          context,
          'Some collection items could not be prepared. Nothing was shared.',
          backgroundColor: Colors.orange,
        );
        return;
      }

      final files = preparations
          .expand((preparation) => preparation.cachedFiles)
          .map((result) => result.file)
          .toList();

      if (files.isEmpty) {
        messenger.hideCurrentSnackBar();
        _showMessage(
          context,
          'Selected collections have no pending GIFs to share',
          backgroundColor: Colors.orange,
        );
        return;
      }

      await Share.shareXFiles(
        files.map((file) => XFile(file.path)).toList(),
        text: '',
      );
      await service.markCollectionsShared(preparations);
      messenger.hideCurrentSnackBar();
    } catch (error) {
      messenger.hideCurrentSnackBar();
      _showMessage(context, 'Error: ${error.toString()}', backgroundColor: Colors.red);
    }
  }

  MediaCacheManager? _cacheManagerOrNull(BuildContext context) {
    try {
      return Provider.of<MediaCacheManager>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  CollectionShareService? _collectionShareServiceOrNull(BuildContext context) {
    try {
      return Provider.of<CollectionShareService>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  Future<File?> _existingLocalFile(GifItem gif) async {
    final candidates = <String?>[gif.url, gif.imageUrl];
    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty || !candidate.startsWith('/')) continue;
      final file = File(candidate);
      if (await file.exists()) return file;
    }
    return null;
  }

  MediaRecord _toMediaRecord(GifItem gif) {
    final mediaUrl = (gif.imageUrl ?? gif.url ?? '').trim();
    final sourceUrl = (gif.url ?? mediaUrl).trim();
    final id = gif.id ??
        MediaIdentity.fromUrls(mediaUrl: mediaUrl, sourceUrl: sourceUrl);

    return MediaRecord(
      id: id,
      sourceUrl: sourceUrl,
      mediaUrl: mediaUrl,
      thumbnailUrl: gif.previewUrl,
      title: gif.title,
      width: gif.width,
      height: gif.height,
      searchText:
          '${gif.title} ${gif.altText ?? ''} $sourceUrl $mediaUrl'.toLowerCase(),
      createdAt: gif.timestamp,
      updatedAt: DateTime.now(),
      lastSeenAt: gif.timestamp,
    );
  }

  Future<void> downloadAndShareGif(
    BuildContext context,
    GifItem gif,
    bool share,
  ) {
    return downloadAndShareGifs(context, [gif], share);
  }

  void _showMessage(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

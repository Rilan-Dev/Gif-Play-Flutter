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
  Future<bool> downloadAndShareGifs(
    BuildContext context,
    List<GifItem> gifs,
    bool share,
  ) async {
    if (gifs.isEmpty) {
      _showMessage(context, 'No GIFs selected', backgroundColor: Colors.orange);
      return false;
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

        final imageUrl = gif.imageUrl?.trim() ?? '';
        final mediaUrl = imageUrl.isNotEmpty ? imageUrl : (gif.url ?? '').trim();
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
        // Cached files use a .bin extension for content-addressed storage.
        // Declare the real media type explicitly so Android/iOS share targets
        // recognize these files as GIF images instead of opaque binaries.
        final shareFiles = <XFile>[];
        final seenPaths = <String>{};
        for (final file in files) {
          if (!await file.exists() || !seenPaths.add(file.path)) continue;
          shareFiles.add(XFile(file.path, mimeType: 'image/gif'));
        }
        if (shareFiles.isEmpty) {
          _showMessage(
            context,
            'No prepared GIF files are available to share',
            backgroundColor: Colors.orange,
          );
          return false;
        }
        await Share.shareXFiles(
          shareFiles,
          text: '',
          sharePositionOrigin: _sharePositionOrigin(context),
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
        return false;
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
      return true;
    } catch (error) {
      messenger.hideCurrentSnackBar();
      _showMessage(context, 'Error: ${error.toString()}', backgroundColor: Colors.red);
      return false;
    }
  }

  /// Shares already-prepared collection files and commits share state only
  /// after the platform share operation returns successfully.
  Future<void> sharePreparedCollections(
    BuildContext context,
    Iterable<CollectionSharePreparation> preparations,
  ) async {
    // Empty collections remain valid reusable lists. Skip them for this share
    // operation instead of failing the other selected, ready collections.
    final items = preparations
        .where((preparation) => !preparation.isEmpty)
        .toList(growable: false);
    final filesByPath = <String, File>{};
    for (final result in items.expand((preparation) => preparation.cachedFiles)) {
      filesByPath[result.file.path] = result.file;
    }
    final files = filesByPath.values.toList(growable: false);

    if (items.isEmpty || files.isEmpty || items.any((item) => !item.isReadyToShare)) {
      _showMessage(
        context,
        'Selected collections are not ready to share',
        backgroundColor: Colors.orange,
      );
      return;
    }

    try {
      final shareFiles = <XFile>[];
      for (final file in files) {
        if (await file.exists()) {
          shareFiles.add(XFile(file.path, mimeType: 'image/gif'));
        }
      }
      if (shareFiles.isEmpty) {
        _showMessage(context, 'No prepared GIF files are available to share',
            backgroundColor: Colors.orange);
        return;
      }
      await Share.shareXFiles(
        shareFiles,
        text: '',
        sharePositionOrigin: _sharePositionOrigin(context),
      );
      final service = _collectionShareServiceOrNull(context);
      if (service == null) {
        throw StateError('CollectionShareService is not configured.');
      }
      await service.markCollectionsShared(items);
    } catch (error) {
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
          preparations.every(
            (preparation) =>
                preparation.isEmpty || preparation.isReadyToShare,
          );

      if (!allReady) {
        messenger.hideCurrentSnackBar();
        _showMessage(
          context,
          'Some collection items could not be prepared. Nothing was shared.',
          backgroundColor: Colors.orange,
        );
        return;
      }

      // The same GIF can belong to multiple collections. Share one copy
      // per local file while keeping every collection's membership intact.
      final filesByPath = <String, File>{};
      for (final result
          in preparations.expand((preparation) => preparation.cachedFiles)) {
        filesByPath[result.file.path] = result.file;
      }
      final files = filesByPath.values.toList(growable: false);

      if (files.isEmpty) {
        messenger.hideCurrentSnackBar();
        _showMessage(
          context,
          'Selected collections have no pending GIFs to share',
          backgroundColor: Colors.orange,
        );
        return;
      }

      final shareFiles = <XFile>[];
      for (final file in files) {
        if (await file.exists()) {
          shareFiles.add(XFile(file.path, mimeType: 'image/gif'));
        }
      }
      if (shareFiles.isEmpty) {
        messenger.hideCurrentSnackBar();
        _showMessage(context, 'No prepared GIF files are available to share',
            backgroundColor: Colors.orange);
        return;
      }
      await Share.shareXFiles(
        shareFiles,
        text: '',
        sharePositionOrigin: _sharePositionOrigin(context),
      );
      await service.markCollectionsShared(preparations);
      messenger.hideCurrentSnackBar();
    } catch (error) {
      messenger.hideCurrentSnackBar();
      _showMessage(context, 'Error: ${error.toString()}', backgroundColor: Colors.red);
    }
  }

  /// iPad requires a source rectangle for the native share popover.
  /// Use the current widget bounds when available; other platforms ignore it.
  Rect? _sharePositionOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
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
    final imageUrl = gif.imageUrl?.trim() ?? '';
    final mediaUrl = imageUrl.isNotEmpty ? imageUrl : (gif.url ?? '').trim();
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

  Future<bool> downloadAndShareGif(
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

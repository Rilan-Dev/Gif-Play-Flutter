import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

import 'file_utils.dart';
import '../models/gif_item.dart';
import 'package:provider/provider.dart';
import '../../data/cache/media_cache_manager.dart';
import '../../data/local/media_identity.dart';
import '../../data/local/models/media_record.dart';

/// Utility class for downloading and sharing media files.
///
/// This class provides methods for downloading and sharing GIFs and other media files.
class DownloadAndShare {
  /// Downloads and shares multiple GIFs.
  ///
  /// If [share] is true, the GIFs will be shared after downloading.
  /// Otherwise, they will just be saved to the device.
  Future<void> downloadAndShareGifs(BuildContext context, List<GifItem> gifs, bool share) async {
    if (gifs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No GIFs selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final List<File> downloadedFiles = [];
    
    // Show loading indicator
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Text(share 
                ? 'Preparing ${gifs.length > 1 ? "${gifs.length} GIFs" : "GIF"} to share...' 
                : 'Downloading ${gifs.length > 1 ? "${gifs.length} GIFs" : "GIF"}...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );
    
    try {
      final cacheManager = _cacheManagerOrNull(context);
      for (final gif in gifs) {
        if (cacheManager != null) {
          final media = _toMediaRecord(gif);
          final cached = await cacheManager.prepareMedia(media);
          if (cached != null) {
            downloadedFiles.add(cached.file);
            continue;
          }
          debugPrint('Cache preparation failed for GIF: ${gif.title}');
          continue;
        }

        File? file;
        String? sourceUrl;
        if (gif.url != null && gif.url!.startsWith('/')) {
          file = File(gif.url!);
          if (await file.exists()) { downloadedFiles.add(file); continue; }
        } else if (gif.imageUrl != null && gif.imageUrl!.startsWith('/')) {
          file = File(gif.imageUrl!);
          if (await file.exists()) { downloadedFiles.add(file); continue; }
        }
        if (gif.imageUrl != null && gif.imageUrl!.startsWith('http')) {
          sourceUrl = gif.imageUrl;
        } else if (gif.url != null && gif.url!.startsWith('http')) {
          sourceUrl = gif.url;
        } else {
          debugPrint('No valid URL found for GIF: ${gif.title}');
          continue;
        }
        try {
          final response = await http.get(Uri.parse(sourceUrl));
          if (response.statusCode != 200) throw Exception('Failed to download: HTTP ${response.statusCode}');
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(sourceUrl)}';
          final hiddenFolder = await FileUtils.getHiddenFolder();
          file = File('${hiddenFolder.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          if (!share) {
            final savedFile = File('${hiddenFolder.path}/saved_$fileName');
            await savedFile.writeAsBytes(response.bodyBytes);
          }
          downloadedFiles.add(file);
        } catch (e) {
          debugPrint('Error downloading GIF: $e');
        }
      }
      // Hide loading indicator
      scaffoldMessenger.hideCurrentSnackBar();
      
      if (share && downloadedFiles.isNotEmpty) {
        // Share the files
        debugPrint('Sharing ${downloadedFiles.length} files');
        await Share.shareXFiles(
          downloadedFiles.map((file) => XFile(file.path)).toList(),
          text: '', // Empty text, no caption will be added when sharing
        );
        
        // Optionally delete the temporary files after sharing
        for (final file in downloadedFiles) {
          if (!file.path.contains('saved_') && file.path.contains('.hidden_folder') && await file.exists()) {
            await file.delete();
          }
        }
      } else if (downloadedFiles.isNotEmpty) {
        // Show success message for download
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${downloadedFiles.length > 1 ? "${downloadedFiles.length} GIFs" : "GIF"} saved successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // No files were downloaded
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No GIFs were processed'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  MediaCacheManager? _cacheManagerOrNull(BuildContext context) {
    try {
      return Provider.of<MediaCacheManager>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  MediaRecord _toMediaRecord(GifItem gif) {
    final mediaUrl = (gif.imageUrl ?? gif.url ?? '').trim();
    final sourceUrl = (gif.url ?? mediaUrl).trim();
    final id = gif.id ?? MediaIdentity.fromUrls(mediaUrl: mediaUrl, sourceUrl: sourceUrl);
    return MediaRecord(
      id: id,
      sourceUrl: sourceUrl,
      mediaUrl: mediaUrl,
      thumbnailUrl: gif.previewUrl,
      title: gif.title,
      width: gif.width,
      height: gif.height,
      searchText: '${gif.title} ${gif.altText ?? ''} $sourceUrl $mediaUrl'.toLowerCase(),
      createdAt: gif.timestamp,
      updatedAt: DateTime.now(),
      lastSeenAt: gif.timestamp,
    );
  }

  /// Downloads and shares a single GIF.
  ///
  /// This is a convenience method for downloading and sharing a single GIF.
  Future<void> downloadAndShareGif(BuildContext context, GifItem gif, bool share) async {
    return downloadAndShareGifs(context, [gif], share);
  }
}


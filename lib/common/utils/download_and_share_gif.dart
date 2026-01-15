import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

import '../models/gif_item.dart';
import 'file_utils.dart';

/// Utility class for downloading and sharing GIFs.
///
/// This class provides methods for downloading and sharing GIFs.
class DownloadAndShareGif {
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
      for (final gif in gifs) {
        File? file;
        String? sourceUrl;
        
        // Check if the file is already local
        if (gif.url != null && gif.url!.startsWith('/')) {
          // File is already local
          file = File(gif.url!);
          if (await file.exists()) {
            downloadedFiles.add(file);
            continue; // Skip to next gif
          }
        } else if (gif.imageUrl != null && gif.imageUrl!.startsWith('/')) {
          // File is already local
          file = File(gif.imageUrl!);
          if (await file.exists()) {
            downloadedFiles.add(file);
            continue; // Skip to next gif
          }
        }
        
        // Determine which URL to use for downloading
        if (gif.url != null && gif.url!.startsWith('http')) {
          sourceUrl = gif.url;
        } else if (gif.imageUrl != null && gif.imageUrl!.startsWith('http')) {
          sourceUrl = gif.imageUrl;
        } else {
          // Skip this gif if no valid URL
          debugPrint('No valid URL found for GIF: ${gif.title}');
          continue;
        }
        
        // Download the file
        try {
          debugPrint('Downloading GIF from: $sourceUrl');
          final response = await http.get(Uri.parse(sourceUrl!));
          
          if (response.statusCode == 200) {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(sourceUrl)}';
            final hiddenFolder = await FileUtils.getHiddenFolder();
            file = File('${hiddenFolder.path}/$fileName');
            await file.writeAsBytes(response.bodyBytes);
            
            // Save the GIF to the hidden folder for later access
            if (!share) {
              // Create a copy for saving with a specific prefix
              final savedFile = File('${hiddenFolder.path}/saved_$fileName');
              await savedFile.writeAsBytes(response.bodyBytes);
              debugPrint('Saved GIF to: ${savedFile.path}');
            }
            
            downloadedFiles.add(file);
            debugPrint('Downloaded GIF to: ${file.path}');
          } else {
            throw Exception('Failed to download: HTTP ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Error downloading GIF: $e');
          // Continue with next gif instead of failing completely
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

  Future<void> downloadAndShareGif(GifItem gif) async {
    try {
      // Download the GIF
      if (gif.url == null) {
        throw Exception('GIF URL is null');
      }
      
      final response = await http.get(Uri.parse(gif.url!));
      
      if (response.statusCode == 200) {
        // Get temporary directory
        final directory = await FileUtils.getHiddenFolder();
        final filePath = '${directory.path}/${gif.id ?? 'unknown'}.gif';
        
        // Save the GIF to the temporary directory
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Share the GIF
        await Share.shareXFiles(
          [XFile(filePath)],
          text: gif.title,
        );
      } else {
        throw Exception('Failed to download GIF: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading and sharing GIF: $e');
      rethrow;
    }
  }
}


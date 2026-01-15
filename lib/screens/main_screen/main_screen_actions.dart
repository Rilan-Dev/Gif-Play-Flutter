import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../common/models/media_item.dart';
import '../../common/models/gif_item.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/utils/download_and_share.dart';
import '../../common/widgets/shimmer_loading.dart';
import '../gif_viewer/gif_viewer_screen.dart';
import '../mood_vibe/mood_vibe_screen.dart';
import 'main_screen_data_service.dart';

/// Class for handling actions in the main screen
class MainScreenActions {
  /// Handles item click based on selection mode
  static void handleItemClick(
    BuildContext context,
    MediaItem item,
    int index,
    bool isSelectionMode,
    Function toggleItemSelection,
    List<MediaItem> filteredItems,
  ) {
    if (isSelectionMode) {
      toggleItemSelection(index);
    } else {
      // Check if the item has the porngifmag.com domain
      if (item.href != null && item.href!.contains('porngifmag.com')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MoodVibeScreen(
              gifLink: item.href ?? '',
              imgLink: item.imageUrl,
              homeItems: filteredItems,  // Pass the filtered items list
              currentIndex: index,        // Pass the current index
            ),
          ),
        );
      } else {
        // Show a dialog with options
        showGifDetailsDialog(context, item);
      }
    }
  }

  /// Shows a dialog with GIF details
  static void showGifDetailsDialog(BuildContext context, MediaItem item) {
    final likedProvider = Provider.of<LikedGifsProvider>(context, listen: false);
    final downloadAndShare = DownloadAndShare();

    // Convert MediaItem to GifItem for provider operations
    final gifItem = GifItem(
      id: item.imageUrl.hashCode.toString(),
      url: item.href ?? '',
      title: item.title ?? 'No Title',
      imageUrl: item.imageUrl,
      timestamp: DateTime.now(),
    );

    final bool isLiked = likedProvider.isGifLiked(gifItem.id ?? '');
    
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    // Fetch GIFs from the URL
    MainScreenDataService.fetchGifsFromUrl(item.href ?? '').then((gifs) {
      // Close loading dialog
      Navigator.pop(context);
      
      // Show the actual dialog with fetched GIFs
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'GIF Details',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Preview image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ShimmerLoading(height: 200),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                  
                  // Like button overlay
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          likedProvider.toggleLikedGif(gifItem);
                          Navigator.pop(context);
                          showGifDetailsDialog(context, item); // Reopen to refresh like status
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Title
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  item.title ?? 'No Title',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              
              // GIFs grid (if any)
              if (gifs.isNotEmpty)
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                      ),
                      itemCount: gifs.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Close dialog
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GifViewerScreen(
                                  gifItems: gifs,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: gifs[index].imageUrl ?? '',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const ShimmerLoading(height: 100),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              
              // View all button
              if (gifs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.fullscreen),
                    label: const Text('View All GIFs'),
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GifViewerScreen(
                            gifItems: gifs,
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              
              // Action buttons - first row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : null,
                      ),
                      label: Text(isLiked ? 'Unlike' : 'Like'),
                      onPressed: () {
                        likedProvider.toggleLikedGif(gifItem);
                        Navigator.pop(context);
                        showGifDetailsDialog(context, item); // Reopen to refresh like status
                      },
                    ),
                  ),
                  
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      onPressed: () {
                        downloadAndShare.downloadAndShareGifs(context, [gifItem], false);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              
              // Action buttons - second row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      onPressed: () {
                        downloadAndShare.downloadAndShareGifs(context, [gifItem], true);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  /// Shares selected items
  static Future<void> shareSelectedItems(
    BuildContext context,
    Set<int> selectedItems,
    List<MediaItem> filteredItems,
    Function toggleSelectionMode,
  ) async {
    final List<GifItem> gifsToShare = selectedItems.map((index) {
      final item = filteredItems[index];
      return GifItem(
        id: item.imageUrl.hashCode.toString(),
        url: item.href ?? '',
        title: item.title ?? 'No Title',
        imageUrl: item.imageUrl,
        timestamp: DateTime.now(),
      );
    }).toList();
    
    final downloadAndShare = DownloadAndShare();
    await downloadAndShare.downloadAndShareGifs(context, gifsToShare, true);
    
    toggleSelectionMode();
  }

  /// Saves selected items
  static Future<void> saveSelectedItems(
    BuildContext context,
    Set<int> selectedItems,
    List<MediaItem> filteredItems,
    Function toggleSelectionMode,
  ) async {
    final List<GifItem> gifsToSave = selectedItems.map((index) {
      final item = filteredItems[index];
      return GifItem(
        id: item.imageUrl.hashCode.toString(),
        url: item.href ?? '',
        title: item.title ?? 'No Title',
        imageUrl: item.imageUrl,
        timestamp: DateTime.now(),
      );
    }).toList();
    
    final downloadAndShare = DownloadAndShare();
    await downloadAndShare.downloadAndShareGifs(context, gifsToSave, false);
    
    toggleSelectionMode();
  }
}


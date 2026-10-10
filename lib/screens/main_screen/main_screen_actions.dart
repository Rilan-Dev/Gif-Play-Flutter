import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../common/models/media_item.dart';
import '../../common/models/gif_item.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/providers/share_queue_provider.dart';
import '../../common/utils/download_and_share.dart';
import '../../common/widgets/shimmer_loading.dart';
import '../../data/local/session_navigation_controller.dart';
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
      // Persist a lightweight tab record before navigating away from the feed.
      // The local tab metadata is available on the next app launch even if the
      // remote detail page is temporarily unavailable.
      final navigation =
          Provider.of<SessionNavigationController>(context, listen: false);
      final spaceId = navigation.activeSpaceId;
      if (spaceId != null) {
        unawaited(navigation.openDetailTab(
          spaceId: spaceId,
          mediaId: item.imageUrl,
          canonicalUrl: item.href ?? item.imageUrl,
          title: item.title ?? 'GIF detail',
          thumbnailUrl: item.imageUrl,
        ));
      }

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
        // Keep the selected Detail Tab as the primary surface. GIF actions are
        // available from its explicit "GIF options" control, avoiding a dialog
        // that immediately covers the tab the user just opened.
      }
    }
  }

  /// Shows a dialog with GIF details
  static void showGifDetailsDialog(BuildContext context, MediaItem item) {
    final likedProvider = Provider.of<LikedGifsProvider>(context, listen: false);
    final downloadAndShare = DownloadAndShare();
    final shareQueueProvider = Provider.of<ShareQueueProvider>(context, listen: false);

    // Convert MediaItem to GifItem for provider operations
    final gifItem = GifItem(
      id: item.imageUrl.hashCode.toString(),
      url: item.imageUrl,
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

      final selectedIndices = <int>{};
      bool isSelecting = false;
      final shareFallbackGif = GifItem(
        id: item.imageUrl.hashCode.toString(),
        url: item.imageUrl,
        title: item.title ?? 'No Title',
        imageUrl: item.imageUrl,
        timestamp: DateTime.now(),
      );
      
      // Show the actual dialog with fetched GIFs
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Dialog(
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
                          final isSelected = selectedIndices.contains(index);
                          return GestureDetector(
                            onTap: () {
                              if (isSelecting) {
                                setState(() {
                                  if (isSelected) {
                                    selectedIndices.remove(index);
                                  } else {
                                    selectedIndices.add(index);
                                  }
                                });
                              } else {
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
                              }
                            },
                            onLongPress: () {
                              if (!isSelecting) {
                                setState(() {
                                  isSelecting = true;
                                  selectedIndices.add(index);
                                });
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: CachedNetworkImage(
                                    imageUrl: gifs[index].imageUrl ?? '',
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const ShimmerLoading(height: 100),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    color: Colors.black.withOpacity(0.35),
                                    child: const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                              ],
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
                        final gifToSave = gifs.isNotEmpty ? gifs.first : shareFallbackGif;
                        downloadAndShare.downloadAndShareGifs(context, [gifToSave], false);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Collect'),
                      onPressed: () {
                        List<GifItem> gifsToCollect;
                        if (isSelecting && selectedIndices.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Select GIFs to collect')),
                          );
                          return;
                        }
                        if (selectedIndices.isNotEmpty) {
                          gifsToCollect = selectedIndices
                              .where((index) => index < gifs.length)
                              .map((index) => gifs[index])
                              .toList();
                        } else if (gifs.isNotEmpty) {
                          gifsToCollect = [gifs.first];
                        } else {
                          gifsToCollect = [shareFallbackGif];
                        }

                        shareQueueProvider.addGifs(gifsToCollect);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added ${gifsToCollect.length} GIFs to share list')),
                        );
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
                        label: Text(isSelecting ? 'Share Selected' : 'Share'),
                        onPressed: () {
                          List<GifItem> gifsToShare;
                          if (isSelecting && selectedIndices.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Select GIFs to share')),
                            );
                            return;
                          }
                          if (selectedIndices.isNotEmpty) {
                            gifsToShare = selectedIndices
                                .where((index) => index < gifs.length)
                                .map((index) => gifs[index])
                                .toList();
                          } else if (gifs.isNotEmpty) {
                            gifsToShare = [gifs.first];
                          } else {
                            gifsToShare = [shareFallbackGif];
                          }

                          downloadAndShare.downloadAndShareGifs(context, gifsToShare, true);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: Icon(isSelecting ? Icons.check_box : Icons.check_box_outline_blank),
                        label: Text(isSelecting ? 'Cancel Select' : 'Select'),
                        onPressed: () {
                          setState(() {
                            if (isSelecting) {
                              isSelecting = false;
                              selectedIndices.clear();
                            } else {
                              isSelecting = true;
                            }
                          });
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


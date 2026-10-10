import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/models/gif_item.dart';
import '../../common/models/media_item.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/providers/share_queue_provider.dart';
import '../../common/utils/download_and_share.dart';
import '../../common/widgets/shimmer_loading.dart';
import '../../screens/gif_viewer_screen.dart';
import 'mood_vibe_screen.dart';
import 'mood_vibe_data_service.dart';

class _DialogSelectionState {
  bool isSelecting = false;
  final Set<int> selectedIndices = {};
}

/// Class for handling actions in the MoodVibe screen
class MoodVibeActions {
  /// Toggles like status for a media item
  static void toggleLike(BuildContext context, MediaItem item) {
    final likedProvider =
        Provider.of<LikedGifsProvider>(context, listen: false);

    // Convert MediaItem to GifItem
    final gifItem = GifItem(
      id: item.imageUrl.hashCode.toString(),
      url: item.href ?? '',
      title: item.title ?? 'No Title',
      imageUrl: item.imageUrl,
      timestamp: DateTime.now(),
    );

    likedProvider.toggleLikedGif(gifItem);

    // Show feedback
    final isNowLiked = likedProvider.isGifLiked(gifItem.id ?? '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(isNowLiked ? 'Added to favorites' : 'Removed from favorites'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handles click on a suggested item
  static void handleSuggestedItemClick(BuildContext context, MediaItem item) {
    // Navigate to a new MoodVibeScreen without replacing the current one
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoodVibeScreen(
          gifLink: item.href ?? '',
          imgLink: item.imageUrl,
        ),
      ),
    );
  }

  /// Shows a dialog with GIF details
  static void showGifDetailsDialog(BuildContext context, MediaItem item) {
    final likedProvider =
        Provider.of<LikedGifsProvider>(context, listen: false);
    final downloadAndShare = DownloadAndShare();
    final shareQueueProvider =
        Provider.of<ShareQueueProvider>(context, listen: false);

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
    MoodVibeDataService.fetchGifsFromUrl(item.href ?? '').then((gifs) {
      // Close loading dialog
      Navigator.pop(context);

      final selectionState = _DialogSelectionState();
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
          builder: (context, setState) => _buildGifDetailsDialog(
            context,
            item,
            gifs,
            isLiked,
            likedProvider,
            downloadAndShare,
            gifItem,
            shareFallbackGif,
            selectionState,
            shareQueueProvider,
            setState,
          ),
        ),
      );
    });
  }

  /// Builds the GIF details dialog
  static Widget _buildGifDetailsDialog(
    BuildContext context,
    MediaItem item,
    List<GifItem> gifs,
    bool isLiked,
    LikedGifsProvider likedProvider,
    DownloadAndShare downloadAndShare,
    GifItem gifItem,
    GifItem shareFallbackGif,
    _DialogSelectionState selectionState,
    ShareQueueProvider shareQueueProvider,
    StateSetter setState,
  ) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dialog content
          _buildDialogContent(
            context,
            item,
            gifs,
            isLiked,
            likedProvider,
            downloadAndShare,
            gifItem,
            shareFallbackGif,
            selectionState,
            shareQueueProvider,
            setState,
          ),
        ],
      ),
    );
  }

  /// Builds the content of the GIF details dialog
  static Widget _buildDialogContent(
    BuildContext context,
    MediaItem item,
    List<GifItem> gifs,
    bool isLiked,
    LikedGifsProvider likedProvider,
    DownloadAndShare downloadAndShare,
    GifItem gifItem,
    GifItem shareFallbackGif,
    _DialogSelectionState selectionState,
    ShareQueueProvider shareQueueProvider,
    StateSetter setState,
  ) {
    return Column(
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
          _buildGifsGrid(
            context,
            gifs,
            selectionState,
            setState,
          ),

        // View all button
        if (gifs.isNotEmpty)
          _buildViewAllButton(context, gifs),

        // Action buttons
        _buildActionButtons(
          context,
          isLiked,
          likedProvider,
          downloadAndShare,
          gifItem,
          shareFallbackGif,
          gifs,
          selectionState,
          shareQueueProvider,
          setState,
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  /// Builds the GIFs grid
  static Widget _buildGifsGrid(
    BuildContext context,
    List<GifItem> gifs,
    _DialogSelectionState selectionState,
    StateSetter setState,
  ) {
    return Flexible(
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
            final isSelected = selectionState.selectedIndices.contains(index);
            return GestureDetector(
              onTap: () {
                if (selectionState.isSelecting) {
                  setState(() {
                    if (isSelected) {
                      selectionState.selectedIndices.remove(index);
                    } else {
                      selectionState.selectedIndices.add(index);
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
                if (!selectionState.isSelecting) {
                  setState(() {
                    selectionState.isSelecting = true;
                    selectionState.selectedIndices.add(index);
                  });
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      gifs[index].imageUrl ?? '',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const ShimmerLoading(height: 100);
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error),
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
    );
  }

  /// Builds the view all button
  static Widget _buildViewAllButton(BuildContext context, List<GifItem> gifs) {
    return Padding(
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
    );
  }

  /// Builds the action buttons
  static Widget _buildActionButtons(
    BuildContext context,
    bool isLiked,
    LikedGifsProvider likedProvider,
    DownloadAndShare downloadAndShare,
    GifItem gifItem,
    GifItem shareFallbackGif,
    List<GifItem> gifs,
    _DialogSelectionState selectionState,
    ShareQueueProvider shareQueueProvider,
    StateSetter setState,
  ) {
    return Column(
      children: [
        // First row of buttons
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
                  // Reopen to refresh like status
                  showGifDetailsDialog(
                    context,
                    MediaItem(
                      imageUrl: gifItem.imageUrl ?? '',
                      title: gifItem.title,
                      href: gifItem.url,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: () {
                  final gifToSave = gifs.isNotEmpty ? gifs.first : shareFallbackGif;
                  downloadAndShare.downloadAndShareGifs(
                      context, [gifToSave], false);
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
                  if (selectionState.isSelecting &&
                      selectionState.selectedIndices.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select GIFs to collect')),
                    );
                    return;
                  }

                  if (selectionState.selectedIndices.isNotEmpty) {
                    gifsToCollect = selectionState.selectedIndices
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
                    SnackBar(
                        content: Text(
                            'Added ${gifsToCollect.length} GIFs to share list')),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),

        // Second row of buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.share),
                label: Text(selectionState.isSelecting ? 'Share Selected' : 'Share'),
                onPressed: () {
                  List<GifItem> gifsToShare;
                  if (selectionState.selectedIndices.isNotEmpty) {
                    gifsToShare = selectionState.selectedIndices
                        .where((index) => index < gifs.length)
                        .map((index) => gifs[index])
                        .toList();
                  } else if (gifs.isNotEmpty) {
                    gifsToShare = [gifs.first];
                  } else {
                    gifsToShare = [shareFallbackGif];
                  }

                  if (selectionState.isSelecting && gifsToShare.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select GIFs to share')),
                    );
                    return;
                  }

                  downloadAndShare.downloadAndShareGifs(
                      context, gifsToShare, true);
                  Navigator.pop(context);
                },
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: Icon(selectionState.isSelecting ? Icons.check_box : Icons.check_box_outline_blank),
                label: Text(selectionState.isSelecting ? 'Cancel Select' : 'Select'),
                onPressed: () {
                  setState(() {
                    if (selectionState.isSelecting) {
                      selectionState.isSelecting = false;
                      selectionState.selectedIndices.clear();
                    } else {
                      selectionState.isSelecting = true;
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
      ],
    );
  }

  /// Shares selected GIFs
  static Future<void> shareSelectedGifs(
    BuildContext context,
    List<GifItem> gifItems,
    Set<int> selectedItems,
    Function disableSelectionMode,
  ) async {
    final downloadAndShare = DownloadAndShare();
    bool isProcessing = false;

    try {
      final selectedGifs = <GifItem>[];
      if (selectedItems.isNotEmpty) {
        for (final index in selectedItems) {
          if (index < gifItems.length) {
            selectedGifs.add(gifItems[index]);
          }
        }
      } else if (gifItems.isNotEmpty) {
        selectedGifs.add(gifItems.first);
      }

      if (selectedGifs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No GIFs to share')),
        );
        return;
      }

      // Show a loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing GIFs for sharing...'),
          duration: Duration(seconds: 1),
        ),
      );

      isProcessing = true;
      await downloadAndShare.downloadAndShareGifs(context, selectedGifs, true);
      isProcessing = false;

      // Close action mode after sharing
      disableSelectionMode();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing GIFs: $e')),
      );
      isProcessing = false;
    }

    return;
  }

  /// Downloads selected GIFs
  static Future<void> downloadSelectedGifs(
    BuildContext context,
    List<GifItem> gifItems,
    Set<int> selectedItems,
    Function disableSelectionMode,
  ) async {
    final downloadAndShare = DownloadAndShare();
    bool isProcessing = false;

    try {
      final selectedGifs = <GifItem>[];
      if (selectedItems.isNotEmpty) {
        for (final index in selectedItems) {
          if (index < gifItems.length) {
            selectedGifs.add(gifItems[index]);
          }
        }
      } else if (gifItems.isNotEmpty) {
        selectedGifs.add(gifItems.first);
      }

      if (selectedGifs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No GIFs to save')),
        );
        return;
      }

      // Show a loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving GIFs...'),
          duration: Duration(seconds: 1),
        ),
      );

      isProcessing = true;
      await downloadAndShare.downloadAndShareGifs(
          context, selectedGifs, false);
      isProcessing = false;

      // Close action mode after downloading
      disableSelectionMode();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving GIFs: $e')),
      );
      isProcessing = false;
    }

    return;
  }

  /// Deletes selected GIFs
  static void deleteSelectedGifs(
    List<GifItem> gifItems,
    List<MediaItem> mediaItems,
    Set<int> selectedItems,
    Function disableSelectionMode,
    Function setState,
  ) {
    setState(() {
      final selectedIndices = List<int>.from(selectedItems);
      selectedIndices.sort((a, b) => b.compareTo(a)); // Sort in descending order

      for (final index in selectedIndices) {
        if (index < gifItems.length) {
          gifItems.removeAt(index);
          mediaItems.removeAt(index);
        }
      }

      disableSelectionMode();
    });
  }
}

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
import '../../data/local/media_identity.dart';
import '../../data/local/models/media_record.dart';
import '../../data/cache/collection_share_controller.dart';
import '../gif_viewer/gif_viewer_screen.dart';
import 'main_screen_data_service.dart';

/// Class for handling actions in the main screen
class MainScreenActions {
  /// Handles item click based on selection mode
  static Future<void> handleItemClick(
    BuildContext context,
    MediaItem item,
    int index,
    bool isSelectionMode,
    Function toggleItemSelection,
    List<MediaItem> filteredItems,
  ) async {
    if (isSelectionMode) {
      toggleItemSelection(index);
    } else {
      // Persist a lightweight tab record before navigating away from the feed.
      // The local tab metadata is available on the next app launch even if the
      // remote detail page is temporarily unavailable.
      final navigation =
          Provider.of<SessionNavigationController>(context, listen: false);
      final spaceId = navigation.activeSpaceId;
      if (spaceId == null) return;
      await navigation.openDetailTab(
        spaceId: spaceId,
        mediaId: item.imageUrl,
        canonicalUrl: item.href ?? item.imageUrl,
        title: item.title ?? 'GIF detail',
        thumbnailUrl: item.imageUrl,
      );

      // Keep every GIF detail inside the MainScreen's persistent tab surface.
      // Pushing a legacy full-screen detail route here hid the Space and child
      // tab controls, so all domains now use the same browser-style navigation.
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
                            onTap: () async {
                              if (isSelecting) {
                                setState(() {
                                  if (isSelected) {
                                    selectedIndices.remove(index);
                                  } else {
                                    selectedIndices.add(index);
                                  }
                                });
                              } else {
                                final navigation =
                                    Provider.of<SessionNavigationController>(
                                  context,
                                  listen: false,
                                );
                                final spaceId = navigation.activeSpaceId;
                                final selectedGif = gifs[index];
                                final imageUrl =
                                    (selectedGif.imageUrl ?? selectedGif.url ?? '')
                                        .trim();
                                Navigator.pop(context);
                                if (spaceId != null && imageUrl.isNotEmpty) {
                                  await navigation.openDetailTab(
                                    spaceId: spaceId,
                                    mediaId: imageUrl,
                                    canonicalUrl: item.href ?? item.imageUrl,
                                    title: selectedGif.title.trim().isNotEmpty
                                        ? selectedGif.title
                                        : 'GIF detail',
                                    thumbnailUrl: imageUrl,
                                  );
                                }
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
                      label: const Text('Share list'),
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
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    label: const Text('Save to collection'),
                    onPressed: () async {
                      List<GifItem> gifsToSave;
                      if (isSelecting && selectedIndices.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Select GIFs to save')),
                        );
                        return;
                      }
                      if (selectedIndices.isNotEmpty) {
                        gifsToSave = selectedIndices
                            .where((index) => index < gifs.length)
                            .map((index) => gifs[index])
                            .toList();
                      } else if (gifs.isNotEmpty) {
                        gifsToSave = [gifs.first];
                      } else {
                        gifsToSave = [shareFallbackGif];
                      }

                      final saved = await _saveGifsToCollection(
                        context,
                        gifsToSave,
                      );
                      if (saved && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    });
  }

  static Future<bool> _saveGifsToCollection(
    BuildContext context,
    List<GifItem> gifs,
  ) async {
    final controller = context.read<CollectionShareController>();
    await controller.loadCollections();
    if (!context.mounted) return false;

    final collectionId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save to collection'),
        content: SizedBox(
          width: 420,
          height: 320,
          child: Consumer<CollectionShareController>(
            builder: (context, state, _) {
              if (state.collections.isEmpty) {
                return const Center(
                  child: Text('Create a collection to save GIFs here.'),
                );
              }
              return ListView(
                children: [
                  for (final collection in state.collections)
                    ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined),
                      title: Text(collection.name),
                      onTap: () => Navigator.pop(dialogContext, collection.id),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('New collection'),
            onPressed: () async {
              final nameController = TextEditingController();
              try {
                final name = await showDialog<String>(
                  context: dialogContext,
                  builder: (nameContext) => AlertDialog(
                    title: const Text('Create collection'),
                    content: TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Collection name',
                      ),
                      onSubmitted: (value) => Navigator.pop(nameContext, value),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(nameContext),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          nameContext,
                          nameController.text,
                        ),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );
                final normalized = name?.trim() ?? '';
                if (normalized.isEmpty || !dialogContext.mounted) return;
                final collection = await controller.createCollection(normalized);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, collection.id);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not create collection: $error')),
                  );
                }
              } finally {
                nameController.dispose();
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (collectionId == null || !context.mounted) return false;

    var savedCount = 0;
    final seenMediaIds = <String>{};
    try {
      for (final gif in gifs) {
        final imageUrl = gif.imageUrl?.trim().isNotEmpty == true
            ? gif.imageUrl!.trim()
            : (gif.url ?? '').trim();
        final uri = Uri.tryParse(imageUrl);
        if (uri == null ||
            (uri.scheme != 'http' && uri.scheme != 'https') ||
            uri.host.isEmpty) {
          continue;
        }
        final sourceUrl = (gif.url?.trim().isNotEmpty == true
                ? gif.url!.trim()
                : imageUrl);
        final id = MediaIdentity.fromUrls(
          mediaUrl: imageUrl,
          sourceUrl: sourceUrl,
        );
        if (!seenMediaIds.add(id)) continue;
        final now = DateTime.now();
        await controller.addMediaToCollection(
          collectionId: collectionId,
          media: MediaRecord(
            id: id,
            sourceUrl: sourceUrl,
            mediaUrl: imageUrl,
            thumbnailUrl: gif.previewUrl ?? imageUrl,
            title: gif.title,
            width: gif.width,
            height: gif.height,
            mimeType: 'image/gif',
            searchText: [
              gif.title,
              gif.altText,
              sourceUrl,
              imageUrl,
            ].whereType<String>().join(' ').toLowerCase(),
            createdAt: gif.timestamp,
            updatedAt: now,
            lastSeenAt: now,
          ),
        );
        savedCount++;
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save GIFs to collection: $error')),
        );
      }
      return false;
    }

    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedCount == 0
              ? 'No valid GIF URLs could be saved'
              : 'Saved $savedCount GIF${savedCount == 1 ? '' : 's'} to collection',
        ),
      ),
    );
    return savedCount > 0;
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


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/liked_gifs_provider.dart';
import 'media_image.dart';

/// A widget for displaying media items in a card layout.
///
/// This widget displays media items in a card layout,
/// with support for selection and like functionality.
class MediaCardView extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final ScrollController? scrollController;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;

  const MediaCardView({
    Key? key,
    required this.mediaItems,
    required this.onItemClick,
    this.onItemLongPress,
    this.scrollController,
    this.onLikeTap,
    this.selectedItems = const {},
    this.isSelectionMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Wrap ListView in a SizedBox with a defined height
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: mediaItems.length,
        itemBuilder: (context, index) {
          final item = mediaItems[index];
          final isSelected = selectedItems.contains(index);

          return Consumer<LikedGifsProvider>(
            builder: (context, likedProvider, child) {
              final bool isLiked = likedProvider.isGifLiked(item.imageUrl.hashCode.toString());

              return Card(
                margin: const EdgeInsets.only(bottom: 24.0),
                clipBehavior: Clip.antiAlias,
                elevation: isSelected ? 8 : 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isSelected
                      ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  )
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => onItemClick(item, index),
                  onLongPress: () => onItemLongPress != null ? onItemLongPress!(item, index) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image section - full width and large height
                      Stack(
                        children: [
                          Hero(
                            tag: 'media_${item.imageUrl.hashCode}',
                            child: SizedBox(
                              width: double.infinity,
                              height: 300, // Very large image height
                              child: MediaImage(
                                imageUrl: item.imageUrl,
                                width: double.infinity,
                                height: 300,
                                fit: BoxFit.cover,
                                placeholderHeight: 300,
                              ),
                            ),
                          ),

                          // Selection indicator
                          if (isSelected)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),

                          // Like button overlay
                          if (onLikeTap != null && !isSelectionMode)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => onLikeTap!(item),
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

                      // Content section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title ?? 'No Title',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            if (item.href != null)
                              Text(
                                item.href!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 16),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('View'),
                                  onPressed: () => onItemClick(item, index),
                                ),
                                if (onLikeTap != null && !isSelectionMode)
                                  TextButton.icon(
                                    icon: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: isLiked ? Colors.red : null,
                                    ),
                                    label: Text(isLiked ? 'Unlike' : 'Like'),
                                    onPressed: () => onLikeTap!(item),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

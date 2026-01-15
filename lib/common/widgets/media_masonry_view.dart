import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/media_item.dart';
import '../providers/liked_gifs_provider.dart';
import 'shimmer_loading.dart';

/// A widget for displaying media items in a masonry layout.
///
/// This widget displays media items in a masonry grid, with support for selection mode
/// and like functionality.
class MediaMasonryView extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;
  final ScrollController? scrollController;

  const MediaMasonryView({
    Key? key,
    required this.mediaItems,
    required this.onItemClick,
    this.onItemLongPress,
    this.onLikeTap,
    this.selectedItems = const {},
    this.isSelectionMode = false,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Split items into two columns
    final leftItems = <MediaItem>[];
    final rightItems = <MediaItem>[];
    final leftIndices = <int>[];
    final rightIndices = <int>[];

    for (int i = 0; i < mediaItems.length; i++) {
      if (i % 2 == 0) {
        leftItems.add(mediaItems[i]);
        leftIndices.add(i);
      } else {
        rightItems.add(mediaItems[i]);
        rightIndices.add(i);
      }
    }

    // Wrap in a SizedBox with defined height to avoid unbounded height error
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Expanded(
              child: _buildColumn(context, leftItems, leftIndices),
            ),
            const SizedBox(width: 8),
            // Right column
            Expanded(
              child: _buildColumn(context, rightItems, rightIndices),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(BuildContext context, List<MediaItem> items, List<int> indices) {
    return Column(
      children: List.generate(
        items.length,
            (i) => _buildItem(context, items[i], indices[i]),
      ),
    );
  }

  Widget _buildItem(BuildContext context, MediaItem item, int index) {
    // Calculate a random-ish height based on the item's hash code
    final heightFactor = 0.8 + ((item.imageUrl.hashCode % 5) / 10); // Between 0.8 and 1.3
    final itemHeight = 200 * heightFactor;
    final isSelected = selectedItems.contains(index);

    return Consumer<LikedGifsProvider>(
      builder: (context, likedProvider, child) {
        final bool isLiked = likedProvider.isGifLiked(item.imageUrl.hashCode.toString());

        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          clipBehavior: Clip.antiAlias,
          elevation: isSelected ? 8 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
                // Image with dynamic height
                Stack(
                  children: [
                    Hero(
                      tag: 'media_${item.imageUrl.hashCode}',
                      child: SizedBox(
                        width: double.infinity,
                        height: itemHeight,
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => ShimmerLoading(height: itemHeight),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              Icons.error,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Selection indicator
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),

                    // Like button overlay
                    if (onLikeTap != null && !isSelectionMode)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onLikeTap!(item),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    item.title ?? 'No Title',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


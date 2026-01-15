import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/media_item.dart';
import '../providers/liked_gifs_provider.dart';
import 'shimmer_loading.dart';

/// A widget that displays media items in a masonry layout for the MoodVibe screen.
///
/// This widget displays media items in a masonry grid, with support for selection mode
/// and like functionality.
class MoodVibeMediaMasonryView extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;
  final ScrollController? scrollController;

  const MoodVibeMediaMasonryView({
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

    return SingleChildScrollView(
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
    final heightFactor = 0.7 + ((item.imageUrl.hashCode % 4) / 10); // Between 0.7 and 1.1
    final itemHeight = 120 * heightFactor;
    final isSelected = selectedItems.contains(index);

    return Consumer<LikedGifsProvider>(
      builder: (context, likedProvider, child) {
        final bool isLiked = likedProvider.isGifLiked(item.imageUrl.hashCode.toString());

        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          clipBehavior: Clip.antiAlias,
          elevation: isSelected ? 6 : 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () => onItemClick(item, index),
            onLongPress: () => onItemLongPress != null ? onItemLongPress!(item, index) : null,
            child: Stack(
              children: [
                // Image with dynamic height
                SizedBox(
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

                // Like button overlay
                if (onLikeTap != null && !isSelectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onLikeTap!(item),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
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


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/media_item.dart';
import '../providers/liked_gifs_provider.dart';
import 'shimmer_loading.dart';

/// A widget that displays media items in a card layout for the MoodVibe screen.
class MoodVibeMediaCardView extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;
  final ScrollController? scrollController;

  const MoodVibeMediaCardView({
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
    // Wrap ListView in a SizedBox with a defined height
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: mediaItems.length,
        itemBuilder: (context, index) {
          final item = mediaItems[index];
          final isSelected = selectedItems.contains(index);

          return Consumer<LikedGifsProvider>(
            builder: (context, likedProvider, child) {
              final isLiked = likedProvider.isGifLiked(item.imageUrl.hashCode.toString());

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                clipBehavior: Clip.antiAlias,
                elevation: isSelected ? 8.0 : 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: isSelected
                      ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => onItemClick(item, index),
                  onLongPress: onItemLongPress != null ? () => onItemLongPress!(item, index) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const ShimmerLoading(height: 120),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          ),

                          // Selection overlay
                          if (isSelected)
                            Positioned.fill(
                              child: Container(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                child: Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 40.0,
                                  ),
                                ),
                              ),
                            ),

                          // Like button
                          if (onLikeTap != null && !isSelectionMode)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: InkWell(
                                  onTap: () => onLikeTap!(item),
                                  child: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? Colors.red : Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Display timestamp instead of title
                            if (item.timestamp != null)
                              Text(
                                _formatTimestamp(item.timestamp!),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),

                            // View button
                            TextButton.icon(
                              icon: const Icon(Icons.visibility, size: 16),
                              label: const Text('View'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(60, 30),
                              ),
                              onPressed: () => onItemClick(item, index),
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}


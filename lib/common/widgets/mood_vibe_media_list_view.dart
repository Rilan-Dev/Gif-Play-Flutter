import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/media_item.dart';
import '../providers/liked_gifs_provider.dart';
import 'shimmer_loading.dart';

/// A widget that displays media items in a list layout for the MoodVibe screen.
///
/// This widget displays media items in a list, with support for selection mode
/// and like functionality.
class MoodVibeMediaListView extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const MoodVibeMediaListView({
    Key? key,
    required this.mediaItems,
    required this.onItemClick,
    this.onItemLongPress,
    this.onLikeTap,
    this.selectedItems = const {},
    this.isSelectionMode = false,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      primary: scrollController == null && !shrinkWrap,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.all(8.0),
      itemCount: mediaItems.length,
      itemBuilder: (context, index) {
        final item = mediaItems[index];
        final isSelected = selectedItems.contains(index);

        return Consumer<LikedGifsProvider>(
          builder: (context, likedProvider, child) {
            final isLiked = likedProvider.isGifLiked(item.imageUrl.hashCode.toString());

            return Card(
              elevation: isSelected ? 8.0 : 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                side: isSelected
                    ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: InkWell(
                onTap: () => onItemClick(item, index),
                onLongPress: onItemLongPress != null ? () => onItemLongPress!(item, index) : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Image
                    SizedBox(
                      width: 120,
                      height: 80,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ShimmerLoading(height: 80),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),

                          // Selection overlay
                          if (isSelected)
                            Container(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              child: Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 30.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: Padding(
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

                            if (onLikeTap != null)
                              InkWell(
                                onTap: () => onLikeTap!(item),
                                child: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : null,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

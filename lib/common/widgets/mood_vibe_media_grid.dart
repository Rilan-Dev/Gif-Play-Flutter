import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/media_item.dart';
import '../providers/liked_gifs_provider.dart';
import 'shimmer_loading.dart';

/// A widget that displays media items in a grid layout for the MoodVibe screen.
///
/// This widget displays media items in a grid, with support for selection mode
/// and like functionality.
class MoodVibeMediaGrid extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;
  final ScrollController? scrollController;

  const MoodVibeMediaGrid({
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
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: mediaItems.length,
      itemBuilder: (context, index) {
        final item = mediaItems[index];
        final isSelected = selectedItems.contains(index);
        
        return Consumer<LikedGifsProvider>(
          builder: (context, likedProvider, child) {
            final isLiked = likedProvider.isGifLiked(item.imageUrl.hashCode.toString());
            
            return GestureDetector(
              onTap: () => onItemClick(item, index),
              onLongPress: onItemLongPress != null ? () => onItemLongPress!(item, index) : null,
              child: Card(
                elevation: isSelected ? 8.0 : 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  side: isSelected
                      ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0)
                      : BorderSide.none,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ShimmerLoading(height: 200),
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
                            size: 40.0,
                          ),
                        ),
                      ),
                    
                    // Like button
                    if (onLikeTap != null && !isSelectionMode)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onLikeTap!(item),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(4),
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
              ),
            );
          },
        );
      },
    );
  }
}


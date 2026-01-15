import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/liked_gifs_provider.dart';
import 'shimmer_loading.dart';

/// A widget for displaying media items in a list layout.
///
/// This widget displays media items in a list layout,
/// with support for selection and like functionality.
class MediaListView extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final ScrollController? scrollController;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;

  const MediaListView({
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
    // Wrap ListView in a Container with a defined height or use Expanded in a Column
    return SizedBox(
      // This ensures the ListView has a bounded height
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
              final bool isLiked = likedProvider.isGifLiked(item.imageUrl.hashCode.toString());

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image section - larger image
                      Stack(
                        children: [
                          Hero(
                            tag: 'media_${item.imageUrl.hashCode}',
                            child: SizedBox(
                              width: 150, // Larger image width
                              height: 150, // Larger image height
                              child: CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const ShimmerLoading(height: 150),
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
                        ],
                      ),

                      // Content section
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title ?? 'No Title',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              if (item.href != null)
                                Text(
                                  item.href!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                  if (onLikeTap != null && !isSelectionMode)
                                    IconButton(
                                      icon: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? Colors.red : null,
                                      ),
                                      onPressed: () => onLikeTap!(item),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () => onItemClick(item, index),
                                  ),
                                ],
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
      ),
    );
  }
}


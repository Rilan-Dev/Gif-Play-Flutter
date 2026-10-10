import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/liked_gifs_provider.dart';
import 'media_image.dart';

/// A widget for displaying media items in a grid layout.
///
/// This widget displays media items in a responsive grid layout,
/// with support for selection and like functionality.
class MediaGrid extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Set<int> selectedItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final ScrollController? scrollController;
  final Function(MediaItem)? onLikeTap;
  final bool isSelectionMode;

  const MediaGrid({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine number of columns based on screen width
        final double width = constraints.maxWidth;
        final int crossAxisCount = width < 600 ? 2 : width < 900 ? 3 : 4;
        
        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.0,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
          ),
          itemCount: mediaItems.length,
          itemBuilder: (context, index) {
            final item = mediaItems[index];
            final isSelected = selectedItems.contains(index);
            
            return Consumer<LikedGifsProvider>(
              builder: (context, likedProvider, child) {
                final bool isLiked = likedProvider.isGifLiked(item.imageUrl.hashCode.toString());
                
                return GestureDetector(
                  onTap: () => onItemClick(item, index),
                  onLongPress: () => onItemLongPress != null ? onItemLongPress!(item, index) : null,
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'media_${item.imageUrl.hashCode}',
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: isSelected ? 8 : 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: isSelected
                                ? BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 3,
                                  )
                                : BorderSide.none,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MediaImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                placeholderHeight: 200,
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Text(
                                    item.title ?? 'No Title',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
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
                      
                      // Like button
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
                );
              },
            );
          },
        );
      },
    );
  }
}

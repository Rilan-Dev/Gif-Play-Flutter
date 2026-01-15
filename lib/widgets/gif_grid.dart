import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../common/models/gif_item.dart';
import '../common/providers/liked_gifs_provider.dart';
import '../common/widgets/shimmer_loading.dart';

class GifGrid extends StatelessWidget {
  final List<GifItem> gifItems;
  final Set<int> selectedItems;
  final Function(GifItem, int) onItemClick;
  final Function(GifItem, int) onItemLongClick;

  const GifGrid({
    Key? key,
    required this.gifItems,
    required this.onItemClick,
    required this.onItemLongClick,
    this.selectedItems = const {},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine number of columns based on screen width
        final double width = constraints.maxWidth;
        final int crossAxisCount = width < 600 ? 2 : width < 900 ? 3 : 4;
        
        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.0,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
          ),
          itemCount: gifItems.length,
          itemBuilder: (context, index) {
            final gifItem = gifItems[index];
            final isSelected = selectedItems.contains(index);
            
            return Consumer<LikedGifsProvider>(
              builder: (context, likedProvider, child) {
                final isLiked = likedProvider.isGifLiked(gifItem.id ?? '');
                
                return GestureDetector(
                  onTap: () => onItemClick(gifItem, index),
                  onLongPress: () => onItemLongClick(gifItem, index),
                  child: Hero(
                    tag: 'gif_${gifItem.id}',
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
                          CachedNetworkImage(
                            imageUrl: gifItem.url ?? gifItem.imageUrl ?? '',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ShimmerLoading(height: 200),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                Icons.error,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          
                          // Selection indicator
                          if (isSelected)
                            Container(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              child: Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 40,
                                ),
                              ),
                            ),
                            
                          // Like button overlay
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  likedProvider.toggleLikedGif(gifItem);
                                },
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
                          
                          // Title overlay
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
                                gifItem.title,
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
                );
              },
            );
          },
        );
      },
    );
  }
}


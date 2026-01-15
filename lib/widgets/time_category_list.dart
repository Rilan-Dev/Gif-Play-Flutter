import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import '../common/models/gif_item.dart';
import '../common/widgets/shimmer_loading.dart';

class TimeCategoryList extends StatelessWidget {
  final Map<String, List<GifItem>> groupedItems;
  final Function(GifItem, int) onItemTap;
  final String Function(GifItem) getTimeAgo;
  final bool Function(GifItem) getLikeStatus;
  final Function(GifItem) onLikeTap;

  const TimeCategoryList({
    Key? key,
    required this.groupedItems,
    required this.onItemTap,
    required this.getTimeAgo,
    required this.getLikeStatus,
    required this.onLikeTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categories = groupedItems.keys.toList();
    
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, categoryIndex) {
        final category = categories[categoryIndex];
        final items = groupedItems[category]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                category,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Items in this category
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isLiked = getLikeStatus(item);
                final isLocalFile = item.url != null && item.url!.isNotEmpty && item.url!.startsWith('/');
                
                return Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => onItemTap(item, index),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // GIF image
                        Hero(
                          tag: 'gif_${item.id}',
                          child: isLocalFile
                              ? Image.file(
                                  File(item.url!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.error, color: Colors.red),
                                    );
                                  },
                                )
                              : CachedNetworkImage(
                                  imageUrl: item.imageUrl ?? item.url ?? '',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const ShimmerLoading(height: 100),
                                  errorWidget: (context, url, error) => const Center(
                                    child: Icon(Icons.error, color: Colors.red),
                                  ),
                                ),
                        ),
                        
                        // Gradient overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.6],
                              ),
                            ),
                          ),
                        ),
                        
                        // Title and time
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title ?? 'No Title',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                getTimeAgo(item),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Like button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onLikeTap(item),
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
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/models/gif_item.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/providers/share_queue_provider.dart';
import 'gif_viewer_data_service.dart';
import 'gif_viewer_actions.dart';

/// UI components for the GIF viewer screen
class GifViewerUI {
  /// Builds the bottom controls
  static Widget buildBottomControls({
    required BuildContext context,
    required Animation<double> animation,
    required int currentPage,
    required int totalItems,
    required PageController pageController,
    required Function(int) toggleLike,
    required Function shareGifs,
    required Function saveGifs,
    required Function collectGifs,
    required Color selectionColor,
  }) {
    final currentGif = context.read<List<GifItem>>()[currentPage];
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * (1 - animation.value)),
          child: Container(
            color: Colors.black.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < totalItems; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == currentPage
                              ? selectionColor
                              : Colors.white.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Navigation controls - icon only
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: currentPage > 0
                          ? () {
                              pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      iconSize: 28,
                      color: Colors.white,
                      disabledColor: Colors.grey.withOpacity(0.5),
                    ),
                    Text(
                      '${currentPage + 1} / $totalItems',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                      onPressed: currentPage < totalItems - 1
                          ? () {
                              pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      iconSize: 28,
                      color: Colors.white,
                      disabledColor: Colors.grey.withOpacity(0.5),
                    ),
                  ],
                ),
                
                // Action buttons
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GifViewerActions.buildQuickActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      onPressed: () => shareGifs(),
                    ),
                    GifViewerActions.buildQuickActionButton(
                      icon: Icons.download,
                      label: 'Save',
                      onPressed: () => saveGifs(),
                    ),
                    Consumer<ShareQueueProvider>(
                      builder: (context, shareQueue, child) {
                        final isCollected = shareQueue.contains(currentGif);
                        return GifViewerActions.buildQuickActionButton(
                          icon: isCollected
                              ? Icons.playlist_add_check
                              : Icons.playlist_add,
                          label: isCollected ? 'Collected' : 'Collect',
                          onPressed: () => collectGifs(),
                          color: isCollected ? Colors.greenAccent : Colors.white,
                        );
                      },
                    ),
                    Consumer<LikedGifsProvider>(
                      builder: (context, likedProvider, child) {
                        final isLiked = likedProvider.isGifLiked(currentGif.id ?? '');
                        return GifViewerActions.buildQuickActionButton(
                          icon: isLiked ? Icons.favorite : Icons.favorite_border,
                          label: isLiked ? 'Unlike' : 'Like',
                          onPressed: () => toggleLike(currentPage),
                          color: isLiked ? Colors.red : Colors.white,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the selection mode bottom bar
  static Widget buildSelectionModeBottomBar({
    required Function shareGifs,
    required Function saveGifs,
    required Function deleteGifs,
    required Function collectGifs,
    required bool isProcessing,
  }) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white, size: 28),
            onPressed: isProcessing ? null : () => deleteGifs(),
            tooltip: 'Delete',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white, size: 28),
            onPressed: isProcessing ? null : () => saveGifs(),
            tooltip: 'Save',
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add, color: Colors.white, size: 28),
            onPressed: isProcessing ? null : () => collectGifs(),
            tooltip: 'Collect',
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white, size: 28),
            onPressed: isProcessing ? null : () => shareGifs(),
            tooltip: 'Share',
          ),
        ],
      ),
    );
  }

  /// Builds the loading indicator
  static Widget buildLoadingIndicator(String message) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds swipe hint indicators
  static Widget buildSwipeHintIndicators({
    required bool canGoNext,
    required bool canGoPrev,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous indicator
              if (canGoPrev)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: 0.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    );
                  },
                ),
              
              // Next indicator
              if (canGoNext)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: 0.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

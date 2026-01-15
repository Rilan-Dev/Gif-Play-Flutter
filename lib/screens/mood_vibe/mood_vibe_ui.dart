import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/models/media_item.dart';
import '../../common/models/gif_item.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/providers/mood_vibe_view_mode_provider.dart';
import '../../common/widgets/media_view_switcher.dart';
import '../../common/widgets/mood_vibe_media_view_switcher.dart';
import 'mood_vibe_data_service.dart';
import 'mood_vibe_actions.dart';

/// UI components for the MoodVibe screen
class MoodVibeUI {
  /// Builds the main content of the MoodVibe screen
  static Widget buildMainContent(
      BuildContext context,
      List<MediaItem> mediaItems,
      List<MediaItem> suggestedItems,
      Function(MediaItem, int) handleItemClick,
      Function(MediaItem, int) handleItemLongPress,
      Set<int> selectedItems,
      bool isSelectionMode,
      ScrollController scrollController,
      ) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Information bar for main GIF content
          _buildInfoBar(context, mediaItems),

          // Main GIFs view
          _buildMainGifsView(
            context,
            mediaItems,
            handleItemClick,
            handleItemLongPress,
            selectedItems,
            isSelectionMode,
          ),

          // Divider and suggestions section
          if (suggestedItems.isNotEmpty) ...[
            const Divider(height: 32, thickness: 1),
            _buildSuggestionsSection(context, suggestedItems),
          ],

          // Bottom padding
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Builds the information bar
  static Widget _buildInfoBar(BuildContext context, List<MediaItem> mediaItems) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Show total count of items
          Text(
            '${mediaItems.length} items',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          // Show when these were fetched
          Text(
            'Updated ${MoodVibeDataService.formatTimestamp(DateTime.now())}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Builds the main GIFs view
  static Widget _buildMainGifsView(
      BuildContext context,
      List<MediaItem> mediaItems,
      Function(MediaItem, int) handleItemClick,
      Function(MediaItem, int) handleItemLongPress,
      Set<int> selectedItems,
      bool isSelectionMode,
      ) {
    return Consumer2<LikedGifsProvider, MoodVibeViewModeProvider>(
      builder: (context, likedProvider, viewModeProvider, child) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.5, // Set a fixed height
          child: MediaViewSwitcher(
            mediaItems: mediaItems,
            onItemClick: handleItemClick,
            onItemLongPress: handleItemLongPress,
            onLikeTap: (item) {
              // Convert MediaItem to GifItem for liking functionality
              final gifItem = GifItem(
                id: item.imageUrl.hashCode.toString(),
                url: item.href ?? '',
                title: item.title ?? 'No Title',
                imageUrl: item.imageUrl,
                timestamp: DateTime.now(),
              );
              likedProvider.toggleLikedGif(gifItem);
            },
            selectedItems: selectedItems,
            isSelectionMode: isSelectionMode,
            viewMode: viewModeProvider.currentViewMode,
          ),
        );
      },
    );
  }

  /// Builds the suggestions section
  static Widget _buildSuggestionsSection(
      BuildContext context,
      List<MediaItem> suggestedItems,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title for suggestions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Suggestions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Suggested thumbnails
        Consumer2<LikedGifsProvider, MoodVibeViewModeProvider>(
          builder: (context, likedProvider, viewModeProvider, child) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.3, // Set a fixed height for suggestions
              child: MoodVibeMediaViewSwitcher(
                mediaItems: suggestedItems,
                onItemClick: (item, index) =>
                    MoodVibeActions.handleSuggestedItemClick(context, item),
                onItemLongPress: (item, index) {
                  MoodVibeActions.showGifDetailsDialog(context, item);
                },
                onLikeTap: (item) {
                  MoodVibeActions.toggleLike(context, item);
                },
                isSelectionMode: false,
                viewMode: viewModeProvider.currentViewMode,
              ),
            );
          },
        ),
      ],
    );
  }

  /// Builds swipe hint indicators
  static Widget buildSwipeHintIndicators(
      bool canGoPrev,
      bool canGoNext,
      ) {
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


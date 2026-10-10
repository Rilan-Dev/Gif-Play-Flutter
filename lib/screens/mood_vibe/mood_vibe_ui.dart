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
      Function(MediaItem, int) handleItemClick,
      Function(MediaItem, int) handleItemLongPress,
      Set<int> selectedItems,
      bool isSelectionMode,
      ScrollController scrollController,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBar(context, mediaItems),
        Expanded(
          child: _buildMainGifsView(
            context,
            mediaItems,
            handleItemClick,
            handleItemLongPress,
            selectedItems,
            isSelectionMode,
            scrollController,
          ),
        ),
      ],
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
      ScrollController scrollController,
      ) {
    return Consumer2<LikedGifsProvider, MoodVibeViewModeProvider>(
      builder: (context, likedProvider, viewModeProvider, child) {
        return MediaViewSwitcher(
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
          scrollController: scrollController,
          viewMode: viewModeProvider.currentViewMode,
        );
      },
    );
  }

  static Widget buildSuggestionsSheet(
      BuildContext context,
      List<MediaItem> suggestedItems,
      ) {
    if (suggestedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      minChildSize: 0.12,
      initialChildSize: 0.12,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final showList = constraints.maxHeight > 220;
            return Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    _buildSuggestionsHeader(context, suggestedItems.length),
                    const Divider(height: 1),
                    if (showList) _buildSuggestionsList(context, suggestedItems),
                    if (!showList) const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildSuggestionsHeader(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggestions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '$count picks • Pull up to explore',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSuggestionsList(
      BuildContext context,
      List<MediaItem> suggestedItems,
      ) {
    return Consumer2<LikedGifsProvider, MoodVibeViewModeProvider>(
      builder: (context, likedProvider, viewModeProvider, child) {
        return MoodVibeMediaViewSwitcher(
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
          scrollController: null,
          viewMode: viewModeProvider.currentViewMode,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          scrollable: false,
        );
      },
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

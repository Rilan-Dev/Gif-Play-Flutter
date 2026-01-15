import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../models/view_mode.dart';
import '../providers/mood_vibe_view_mode_provider.dart';
import 'mood_vibe_media_grid.dart';
import 'mood_vibe_media_list_view.dart';
import 'mood_vibe_media_card_view.dart';
import 'mood_vibe_media_masonry_view.dart';

/// A widget that switches between different view modes for media items in the MoodVibe screen.
///
/// This widget displays media items in different layouts based on the current view mode,
/// with support for grid, list, card, and masonry views.
class MoodVibeMediaViewSwitcher extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;
  final ScrollController? scrollController;
  final ViewMode? viewMode;

  const MoodVibeMediaViewSwitcher({
    Key? key,
    required this.mediaItems,
    required this.onItemClick,
    this.onItemLongPress,
    this.onLikeTap,
    this.selectedItems = const {},
    this.isSelectionMode = false,
    this.scrollController,
    this.viewMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use the provided viewMode if available, otherwise get it from the provider
    final currentViewMode = viewMode ??
        Provider.of<MoodVibeViewModeProvider>(context).currentViewMode;

    switch (currentViewMode) {
      case ViewMode.grid:
        return MoodVibeMediaGrid(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
      case ViewMode.list:
        return MoodVibeMediaListView(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
      case ViewMode.card:
        return MoodVibeMediaCardView(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
      case ViewMode.masonry:
        return MoodVibeMediaMasonryView(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
      default:
        return MoodVibeMediaGrid(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
    }
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../models/view_mode.dart';
import '../providers/view_mode_provider.dart';
import 'media_grid.dart';
import 'media_list_view.dart';
import 'media_card_view.dart';
import 'media_masonry_view.dart';

/// A widget that switches between different view modes for media items.
///
/// This widget displays media items in different layouts based on the current view mode,
/// with support for grid, list, card, and masonry views.
class MediaViewSwitcher extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongPress;
  final Function(MediaItem)? onLikeTap;
  final Set<int> selectedItems;
  final bool isSelectionMode;
  final ScrollController? scrollController;
  final ViewMode? viewMode;

  const MediaViewSwitcher({
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
        Provider.of<ViewModeProvider>(context).currentViewMode;

    switch (currentViewMode) {
      case ViewMode.grid:
        return MediaGrid(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
      case ViewMode.list:
        return MediaListView(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
      case ViewMode.card:
        return MediaCardView(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
      case ViewMode.masonry:
        return MediaMasonryView(
          mediaItems: mediaItems,
          onItemClick: onItemClick,
          onItemLongPress: onItemLongPress,
          onLikeTap: onLikeTap,
          selectedItems: selectedItems,
          isSelectionMode: isSelectionMode,
          scrollController: scrollController,
        );
      default:
        return MediaGrid(
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


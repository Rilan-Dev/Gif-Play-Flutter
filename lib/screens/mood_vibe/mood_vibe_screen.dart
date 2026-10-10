import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/models/gif_item.dart';
import '../../common/models/media_item.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/providers/mood_vibe_view_mode_provider.dart';
import '../../common/providers/share_queue_provider.dart';
import '../../common/widgets/shimmer_loading.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/error_state.dart';
import '../../common/widgets/action_mode_bottom_bar.dart';
import '../../common/animations/slide_animation.dart';
import '../../common/mixins/selection_state_mixin.dart';
import '../../common/widgets/mood_vibe_view_mode_selector.dart';
import '../../common/widgets/global_share_fab.dart';
import '../../screens/gif_viewer/gif_viewer_screen.dart';

import 'mood_vibe_data_service.dart';
import 'mood_vibe_actions.dart';
import 'mood_vibe_ui.dart';  // Make sure this import is present

class MoodVibeScreen extends StatefulWidget {
  final String gifLink;
  final String imgLink;
  final List<MediaItem>? homeItems;
  final int currentIndex;

  const MoodVibeScreen({
    Key? key,
    required this.gifLink,
    required this.imgLink,
    this.homeItems,
    this.currentIndex = 0,
  }) : super(key: key);

  @override
  _MoodVibeScreenState createState() => _MoodVibeScreenState();
}

class _MoodVibeScreenState extends State<MoodVibeScreen>
    with TickerProviderStateMixin, SelectionStateMixin {
  final List<GifItem> _gifItems = [];
  final List<MediaItem> _mediaItems = [];
  final List<MediaItem> _suggestedItems = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isProcessing = false;

  // For next GIF navigation
  bool _isLoadingNext = false;
  bool _canGoNext = false;
  bool _canGoPrev = false;

  // For sliding animation
  late SlideAnimationController _slideController;

  // Scroll controller for the main scroll view
  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchData();

    // Check if we have home items and can navigate
    _updateNavigationState();

    // Initialize animation controller
    _slideController = SlideAnimationController(
      vsync: this,
      direction: SlideDirection.horizontal,
    );
  }

  void _updateNavigationState() {
    if (widget.homeItems != null && widget.homeItems!.isNotEmpty) {
      setState(() {
        _canGoNext = widget.currentIndex < widget.homeItems!.length - 1;
        _canGoPrev = widget.currentIndex > 0;
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final result = await MoodVibeDataService.fetchGifData(widget.gifLink);

      if (mounted) {
        setState(() {
          _gifItems.addAll(result['gifItems']);
          _mediaItems.addAll(result['mediaItems']);
          _suggestedItems.addAll(result['suggestedItems']);
          _hasError = result['hasError'];
          _errorMessage = result['errorMessage'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }

    // Update navigation state after loading
    _updateNavigationState();
  }

  void _handleSwipe(DragEndDetails details) {
    // Only handle swipes when not in selection mode and not loading
    if (isSelectionMode || _isLoading || _isLoadingNext) return;

    // Check if we have home items to navigate through
    if (widget.homeItems == null || widget.homeItems!.isEmpty) return;

    // Determine swipe direction based on velocity
    final velocity = details.velocity.pixelsPerSecond.dx;
    final swipeThreshold = 300.0; // Minimum velocity to trigger navigation

    if (velocity < -swipeThreshold && _canGoNext) {
      // Swipe left -> go to next
      _navigateToNextGif();
    } else if (velocity > swipeThreshold && _canGoPrev) {
      // Swipe right -> go to previous
      _navigateToPrevGif();
    }
  }

  void _navigateToNextGif() {
    if (widget.homeItems == null ||
        widget.currentIndex >= widget.homeItems!.length - 1 ||
        _isLoadingNext) return;

    setState(() {
      _isLoadingNext = true;
      _slideController.isForward = true;
    });

    // Reset controller and start slide animation
    _slideController.forward().then((_) {
      // Navigate to next GIF when animation completes
      final nextItem = widget.homeItems![widget.currentIndex + 1];

      // Use push instead of pushReplacement to maintain back stack
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MoodVibeScreen(
            gifLink: nextItem.href ?? '',
            imgLink: nextItem.imageUrl,
            homeItems: widget.homeItems,
            currentIndex: widget.currentIndex + 1,
          ),
        ),
      ).then((_) {
        // This will be called when returning from the pushed route
        if (mounted) {
          setState(() {
            _isLoadingNext = false;
          });
        }
      });
    });
  }

  void _navigateToPrevGif() {
    if (widget.homeItems == null || widget.currentIndex <= 0 || _isLoadingNext)
      return;

    setState(() {
      _isLoadingNext = true;
      _slideController.isForward = false;
    });

    // Reset controller and start slide animation
    _slideController.forward().then((_) {
      // Instead of navigating to previous, just pop this screen
      // since the previous screen should already be in the back stack
      Navigator.pop(context);
    });
  }

  // Add this method to handle back button press
  @override
  Future<bool> didPopRoute() async {
    if (isSelectionMode) {
      // If in selection mode, just disable it instead of popping
      disableSelectionMode();
      return true;
    }
    return false; // Let the system handle the back button
  }

  // Add this method to handle WillPopScope
  Future<bool> _onWillPop() async {
    if (isSelectionMode) {
      // If in selection mode, just disable it instead of popping
      disableSelectionMode();
      return false; // Don't pop the route
    }
    return true; // Allow popping the route
  }

  void _handleItemClick(MediaItem item, int index) {
    handleItemTap(index, () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GifViewerScreen(
            gifItems: _gifItems,
            initialIndex: index,
            homeItems: widget.homeItems,
            homeCurrentIndex: widget.currentIndex,
          ),
        ),
      );
    });
  }

  void _handleItemLongPress(MediaItem item, int index) {
    enableSelectionMode(index);
  }

  Future<void> _shareSelectedGifs() async {
    setState(() {
      _isProcessing = true;
    });

    await MoodVibeActions.shareSelectedGifs(
      context,
      _gifItems,
      selectedItems,
      disableSelectionMode,
    );

    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _downloadSelectedGifs() async {
    setState(() {
      _isProcessing = true;
    });

    await MoodVibeActions.downloadSelectedGifs(
      context,
      _gifItems,
      selectedItems,
      disableSelectionMode,
    );

    setState(() {
      _isProcessing = false;
    });
  }

  void _deleteSelectedGifs() {
    MoodVibeActions.deleteSelectedGifs(
      _gifItems,
      _mediaItems,
      selectedItems,
      disableSelectionMode,
      setState,
    );
  }

  void _collectSelectedGifs() {
    if (selectedItems.isEmpty) return;
    final shareQueue = Provider.of<ShareQueueProvider>(context, listen: false);
    final gifsToCollect =
        selectedItems.map((index) => _gifItems[index]).toList();
    shareQueue.addGifs(gifsToCollect);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Added ${gifsToCollect.length} GIFs to share list')),
    );
    disableSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: SlideAnimatedWidget(
        controller: _slideController,
        child: Scaffold(
          appBar: AppBar(
            title: isSelectionMode
                ? Text('${selectedCount} selected')
                : widget.homeItems != null
                ? Text(
                'GIF ${widget.currentIndex + 1}/${widget.homeItems!.length}')
                : const Text('GIF Details'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            actions: isSelectionMode
                ? [
              // Only show close button in selection mode
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: disableSelectionMode,
                tooltip: 'Cancel selection',
              ),
            ]
                : [
              // Show MoodVibeViewModeSelector in normal mode
              const MoodVibeViewModeSelector(),
            ],
          ),
          body: GestureDetector(
            onHorizontalDragEnd: _handleSwipe,
            child: Stack(
              children: [
                // Main content
                if (!_isLoading && !_hasError && _mediaItems.isNotEmpty)
                  Positioned.fill(
                    child: MoodVibeUI.buildMainContent(
                      context,
                      _mediaItems,
                      _handleItemClick,
                      _handleItemLongPress,
                      selectedItems,
                      isSelectionMode,
                      _mainScrollController,
                    ),
                  )
                else if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_hasError)
                  ErrorState(
                    message: 'Failed to load GIFs',
                    details: _errorMessage,
                    onRetry: _fetchData,
                  )
                else
                  const EmptyState(
                    icon: Icons.image_not_supported,
                    title: 'No GIFs found',
                  ),

                if (!_isLoading &&
                    !_hasError &&
                    _suggestedItems.isNotEmpty &&
                    !isSelectionMode)
                  Positioned.fill(
                    child: MoodVibeUI.buildSuggestionsSheet(
                      context,
                      _suggestedItems,
                    ),
                  ),

                // Swipe hint indicators
                if (widget.homeItems != null &&
                    !_isLoading &&
                    !_isLoadingNext &&
                    !isSelectionMode)
                  MoodVibeUI.buildSwipeHintIndicators(_canGoPrev, _canGoNext),

                // Bottom action bar in selection mode
                if (isSelectionMode)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ActionModeBottomBar(
                      selectedCount: selectedCount,
                      actions: [
                        ActionItem(
                          icon: Icons.delete,
                          label: 'Delete',
                          onPressed: _deleteSelectedGifs,
                        ),
                        ActionItem(
                          icon: Icons.download,
                          label: 'Save',
                          onPressed: _downloadSelectedGifs,
                        ),
                        ActionItem(
                          icon: Icons.playlist_add,
                          label: 'Collect',
                          onPressed: _collectSelectedGifs,
                        ),
                        ActionItem(
                          icon: Icons.share,
                          label: 'Share',
                          onPressed: _shareSelectedGifs,
                        ),
                      ],
                      isDisabled: _isProcessing,
                    ),
                  ),

                // Loading overlay
                if (_isProcessing || _isLoadingNext)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: isSelectionMode ? null : const GlobalShareFab(),
        ),
      ),
    );
  }
}

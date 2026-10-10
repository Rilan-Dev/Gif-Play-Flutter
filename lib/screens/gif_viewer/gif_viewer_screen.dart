import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/models/gif_item.dart';
import '../../common/models/media_item.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/providers/share_queue_provider.dart';
import '../../common/animations/slide_animation.dart';
import '../../common/mixins/selection_state_mixin.dart';
import '../../common/widgets/global_share_fab.dart';
import '../mood_vibe/mood_vibe_screen.dart';

import 'gif_viewer_data_service.dart';
import 'gif_viewer_actions.dart';
import 'gif_viewer_ui.dart';

class GifViewerScreen extends StatefulWidget {
  final List<GifItem> gifItems;
  final int initialIndex;
  final List<MediaItem>? homeItems;
  final int homeCurrentIndex;

  const GifViewerScreen({
    Key? key,
    required this.gifItems,
    required this.initialIndex,
    this.homeItems,
    this.homeCurrentIndex = 0,
  }) : super(key: key);

  @override
  _GifViewerScreenState createState() => _GifViewerScreenState();
}

class _GifViewerScreenState extends State<GifViewerScreen> with TickerProviderStateMixin, SelectionStateMixin {
  late PageController _pageController;
  late int _currentPage;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isControlsVisible = true;
  bool _isProcessing = false;

  // For swipe navigation between home items
  bool _canGoNext = false;
  bool _canGoPrev = false;
  bool _isNavigating = false;

  // For sliding animation
  late SlideAnimationController _slideController;

  // Define a neutral selection color instead of using the theme primary color
  final Color _selectionColor = Colors.blue.shade700;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: _currentPage);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.value = 1.0; // Start with controls visible
    
    // Initialize slide controller for home navigation
    _slideController = SlideAnimationController(
      vsync: this,
      direction: SlideDirection.horizontal,
    );
    
    // Update navigation state
    _updateNavigationState();
  }

  void _updateNavigationState() {
    if (widget.homeItems != null && widget.homeItems!.isNotEmpty) {
      setState(() {
        _canGoNext = widget.homeCurrentIndex < widget.homeItems!.length - 1;
        _canGoPrev = widget.homeCurrentIndex > 0;
      });
    }
  }

  void _toggleControls() {
    if (isSelectionMode) return; // Don't toggle controls in selection mode
    
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
    
    if (_isControlsVisible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _handleSwipe(DragEndDetails details) {
    // Only handle swipes when not in selection mode and not processing
    if (isSelectionMode || _isProcessing || _isNavigating) return;
    
    // Check if we have home items to navigate through
    if (widget.homeItems == null || widget.homeItems!.isEmpty) return;
    
    // Determine swipe direction based on velocity
    final velocity = details.velocity.pixelsPerSecond.dx;
    final swipeThreshold = 300.0; // Minimum velocity to trigger navigation
    
    if (velocity < -swipeThreshold && _canGoNext) {
      // Swipe left -> go to next
      _navigateToNextHomeItem();
    } else if (velocity > swipeThreshold && _canGoPrev) {
      // Swipe right -> go to previous
      _navigateToPrevHomeItem();
    }
  }

  void _navigateToNextHomeItem() {
    if (widget.homeItems == null || 
        widget.homeCurrentIndex >= widget.homeItems!.length - 1 || 
        _isNavigating) return;

    setState(() {
      _isNavigating = true;
      _slideController.isForward = true;
    });

    // Reset controller and start slide animation
    _slideController.forward().then((_) {
      // Navigate to next item when animation completes
      final nextItem = widget.homeItems![widget.homeCurrentIndex + 1];
      
      // Use push instead of pushReplacement to maintain back stack
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MoodVibeScreen(
            gifLink: nextItem.href ?? '',
            imgLink: nextItem.imageUrl,
            homeItems: widget.homeItems,
            currentIndex: widget.homeCurrentIndex + 1,
          ),
        ),
      ).then((_) {
        // This will be called when returning from the pushed route
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      });
    });
  }

  void _navigateToPrevHomeItem() {
    if (widget.homeItems == null || 
        widget.homeCurrentIndex <= 0 || 
        _isNavigating) return;

    setState(() {
      _isNavigating = true;
      _slideController.isForward = false;
    });

    // Reset controller and start slide animation
    _slideController.forward().then((_) {
      // Instead of navigating to previous, just pop this screen
      // since the previous screen should already be in the back stack
      Navigator.pop(context);
    });
  }

  void _toggleLike(int index) {
    GifViewerActions.toggleLike(context, index, widget.gifItems);
    setState(() {}); // Force refresh
  }

  Future<void> _shareSelectedGifs() async {
    await GifViewerActions.shareSelectedGifs(
      context: context,
      gifItems: widget.gifItems,
      currentPage: _currentPage,
      selectedItems: selectedItems,
      disableSelectionMode: disableSelectionMode,
      setProcessing: (value) => setState(() => _isProcessing = value),
    );
  }

  Future<void> _saveSelectedGifs() async {
    await GifViewerActions.saveSelectedGifs(
      context: context,
      gifItems: widget.gifItems,
      currentPage: _currentPage,
      selectedItems: selectedItems,
      disableSelectionMode: disableSelectionMode,
      setProcessing: (value) => setState(() => _isProcessing = value),
    );
  }

  void _deleteSelectedGifs() {
    // Add delete functionality here
    disableSelectionMode();
  }

  void _collectSelectedGifs() {
    final shareQueue = Provider.of<ShareQueueProvider>(context, listen: false);
    final List<GifItem> gifsToCollect;
    if (selectedItems.isEmpty) {
      gifsToCollect = [widget.gifItems[_currentPage]];
    } else {
      gifsToCollect = selectedItems.map((index) => widget.gifItems[index]).toList();
    }

    shareQueue.addGifs(gifsToCollect);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${gifsToCollect.length} GIFs to share list')),
    );

    if (selectedItems.isNotEmpty) {
      disableSelectionMode();
    }
  }

  Future<bool> _onWillPop() async {
    if (isSelectionMode) {
      // If in selection mode, just disable it instead of popping
      disableSelectionMode();
      return false; // Don't pop the route
    }
    return true; // Allow popping the route
  }

  @override
  Widget build(BuildContext context) {
    return Provider<List<GifItem>>.value(
      value: widget.gifItems,
      child: Builder(
        builder: (context) => WillPopScope(
          onWillPop: _onWillPop,
          child: SlideAnimatedWidget(
            controller: _slideController,
            child: Scaffold(
              backgroundColor: Colors.black,
              extendBodyBehindAppBar: true,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: isSelectionMode ? 1.0 : _animation.value,
                      child: AppBar(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        elevation: 0,
                        iconTheme: const IconThemeData(color: Colors.white),
                        title: isSelectionMode 
                            ? Text('${selectedCount} selected', style: const TextStyle(color: Colors.white))
                            : widget.homeItems != null
                                ? Text(
                                    'GIF ${widget.homeCurrentIndex + 1}/${widget.homeItems!.length}',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : Text(
                                    widget.gifItems[_currentPage].title,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                        leading: isSelectionMode
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: disableSelectionMode,
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                      ),
                    );
                  },
                ),
              ),
              body: GestureDetector(
                onHorizontalDragEnd: _handleSwipe,
                child: Stack(
                  children: [
                    // Main content
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.gifItems.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final isSelected = selectedItems.contains(index);
                        return GestureDetector(
                          onTap: () {
                            if (isSelectionMode) {
                              toggleItemSelection(index);
                            } else {
                              _toggleControls();
                            }
                          },
                          onLongPress: () {
                            if (!isSelectionMode) {
                              enableSelectionMode(index);
                            }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // GIF content
                              GifViewerDataService.buildGifContent(widget.gifItems[index], index),
                              
                              // Centered selection indicator
                              if (isSelectionMode && isSelected)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(0.7),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    // Swipe hint indicators
                    if (widget.homeItems != null && !_isProcessing && !_isNavigating && !isSelectionMode)
                      GifViewerUI.buildSwipeHintIndicators(
                        canGoNext: _canGoNext,
                        canGoPrev: _canGoPrev,
                      ),
                    
                    // Bottom controls - only show in normal mode
                    if (!isSelectionMode)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: GifViewerUI.buildBottomControls(
                          context: context,
                          animation: _animation,
                          currentPage: _currentPage,
                          totalItems: widget.gifItems.length,
                          pageController: _pageController,
                          toggleLike: _toggleLike,
                          shareGifs: _shareSelectedGifs,
                          saveGifs: _saveSelectedGifs,
                          collectGifs: _collectSelectedGifs,
                          selectionColor: _selectionColor,
                        ),
                      ),
                    
                    // Bottom action bar in selection mode
                    if (isSelectionMode)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: GifViewerUI.buildSelectionModeBottomBar(
                          shareGifs: _shareSelectedGifs,
                          saveGifs: _saveSelectedGifs,
                          deleteGifs: _deleteSelectedGifs,
                          collectGifs: _collectSelectedGifs,
                          isProcessing: _isProcessing,
                        ),
                      ),
                    
                    // Loading indicator
                    if (_isProcessing || _isNavigating)
                      GifViewerUI.buildLoadingIndicator(
                        _isNavigating 
                            ? 'Loading next GIF...'
                            : 'Processing ${selectedItems.isEmpty ? "GIF" : "${selectedCount} GIFs"}...'
                      ),
                  ],
                ),
              ),
              floatingActionButton: const GlobalShareFab(),
              floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}

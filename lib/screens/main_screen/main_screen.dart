import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';

import '../../common/models/media_item.dart';
import '../../common/models/gif_item.dart';
import '../../common/providers/theme_provider.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/providers/view_mode_provider.dart';
import '../../common/widgets/view_mode_selector.dart';
import '../../common/widgets/shimmer_loading.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/error_state.dart';
import '../../common/widgets/media_view_switcher.dart';

import '../viewed_gifs_screen.dart';
import '../share_gif_screen.dart';
import '../liked_gifs_screen.dart';

import 'main_screen_data_service.dart';
import 'main_screen_actions.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<MediaItem> _mediaItems = [];
  final List<MediaItem> _filteredItems = [];
  bool _isLoading = false;
  bool _isSearchVisible = false;
  int _currentPage = 1;
  int _totalPages = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _hasError = false;
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();
  final Set<int> _selectedItems = {};
  bool _isSelectionMode = false;
  Set<int>? _visitedPages;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        !_hasError &&
        (_totalPages == 0 || _currentPage <= _totalPages)) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final result = await MainScreenDataService.fetchData(
        currentPage: _currentPage,
        mediaItems: _mediaItems,
        filteredItems: _filteredItems,
        searchController: _searchController,
        visitedPages: _visitedPages,
        totalPages: _totalPages,
      );
      
      setState(() {
        _mediaItems.clear();
        _mediaItems.addAll(result['mediaItems']);
        _filteredItems.clear();
        _filteredItems.addAll(result['filteredItems']);
        _hasError = result['hasError'];
        _errorMessage = result['errorMessage'];
        _visitedPages = result['visitedPages'];
        _totalPages = result['totalPages'];
        
        // Shuffle the items after fetching
        if (_mediaItems.isNotEmpty) {
          final random = Random();
          _mediaItems.shuffle(random);
          
          // Also update filtered items if search is not active
          if (_searchController.text.isEmpty) {
            _filteredItems.clear();
            _filteredItems.addAll(_mediaItems);
          }
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    // Keep existing items and add more
    final int previousCount = _mediaItems.length;
    
    await _fetchData();
    
    // Show a message about how many new items were added
    final int newCount = _mediaItems.length - previousCount;
    if (newCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $newCount new GIFs'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    // Additional shuffle after refresh for better randomness
    if (_mediaItems.isNotEmpty) {
      setState(() {
        _mediaItems.shuffle();
        if (_searchController.text.isEmpty) {
          _filteredItems.clear();
          _filteredItems.addAll(_mediaItems);
        }
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems.clear();
        _filteredItems.addAll(_mediaItems);
      } else {
        _filteredItems.clear();
        _filteredItems.addAll(_mediaItems.where(
          (item) => item.title?.toLowerCase().contains(query.toLowerCase()) ?? false
        ));
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(index);
      }
    });
  }

  Future<void> _shareSelectedItems() async {
    await MainScreenActions.shareSelectedItems(
      context,
      _selectedItems,
      _filteredItems,
      _toggleSelectionMode,
    );
  }

  Future<void> _saveSelectedItems() async {
    await MainScreenActions.saveSelectedItems(
      context,
      _selectedItems,
      _filteredItems,
      _toggleSelectionMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text(
                '${_selectedItems.length} selected',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Text(
                'GIF Play',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
        centerTitle: true,
        elevation: 2,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                // Selection mode actions with improved spacing
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share selected',
                    onPressed: _selectedItems.isNotEmpty ? _shareSelectedItems : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, left: 4.0),
                  child: IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Save selected',
                    onPressed: _selectedItems.isNotEmpty ? _saveSelectedItems : null,
                  ),
                ),
              ]
            : [
                // Normal mode actions with improved spacing and consistency
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search',
                    onPressed: () {
                      setState(() {
                        _isSearchVisible = !_isSearchVisible;
                        if (!_isSearchVisible) {
                          _searchController.clear();
                          _filterItems('');
                        }
                      });
                    },
                  ),
                ),
                // View mode selector
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: ViewModeSelector(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: IconButton(
                    icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                    tooltip: 'Toggle theme',
                    onPressed: () {
                      themeProvider.toggleTheme();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 8.0),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'More options',
                    onSelected: (value) {
                      if (value == 'viewed_gifs') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ViewedGifsScreen()),
                        );
                      } else if (value == 'saved_gifs') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ShareGifScreen()),
                        );
                      } else if (value == 'liked_gifs') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LikedGifsScreen()),
                        );
                      } else if (value == 'select_mode') {
                        _toggleSelectionMode();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        const PopupMenuItem<String>(
                          value: 'select_mode',
                          child: ListTile(
                            leading: Icon(Icons.check_box_outline_blank),
                            title: Text('Select Multiple'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'viewed_gifs',
                          child: ListTile(
                            leading: Icon(Icons.history),
                            title: Text('Viewed GIFs'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'saved_gifs',
                          child: ListTile(
                            leading: Icon(Icons.save),
                            title: Text('Saved GIFs'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'liked_gifs',
                          child: ListTile(
                            leading: Icon(Icons.favorite),
                            title: Text('Liked GIFs'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ];
                    },
                  ),
                ),
              ],
      ),
      body: Column(
        children: [
          if (_isSearchVisible)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _filterItems,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items: ${_filteredItems.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_hasError)
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: _refreshData,
                  ),
              ],
            ),
          ),
          if (_hasError)
            ErrorState(
              message: 'Error loading GIFs',
              details: _errorMessage,
              onRetry: _refreshData,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: _filteredItems.isEmpty && !_isLoading
                  ? EmptyState(
                      icon: Icons.image_not_supported,
                      title: 'No GIFs found',
                      actionLabel: 'Refresh',
                      onAction: _refreshData,
                    )
                  : Consumer<LikedGifsProvider>(
                      builder: (context, likedProvider, child) {
                        return Consumer<ViewModeProvider>(
                          builder: (context, viewModeProvider, child) {
                            return MediaViewSwitcher(
                              mediaItems: _filteredItems,
                              onItemClick: (item, index) => MainScreenActions.handleItemClick(
                                context,
                                item,
                                index,
                                _isSelectionMode,
                                _toggleItemSelection,
                                _filteredItems,
                              ),
                              onItemLongPress: (item, index) {
                                if (_isSelectionMode) {
                                  _toggleItemSelection(index);
                                } else {
                                  MainScreenActions.showGifDetailsDialog(context, item);
                                }
                              },
                              scrollController: _scrollController,
                              onLikeTap: (item) {
                                // Convert MediaItem to GifItem for liking
                                final gifItem = GifItem(
                                  id: item.imageUrl.hashCode.toString(),
                                  url: item.href ?? '',
                                  title: item.title ?? 'No Title',
                                  imageUrl: item.imageUrl,
                                );
                                likedProvider.toggleLikedGif(gifItem);
                              },
                              selectedItems: _selectedItems,
                              isSelectionMode: _isSelectionMode,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: ShimmerLoading(height: 4),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}


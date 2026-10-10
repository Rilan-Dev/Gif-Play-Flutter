import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import '../../common/widgets/session_navigation_strip.dart';
import '../../common/widgets/detail_tab_content.dart';
import '../../common/widgets/global_share_fab.dart';
import '../../data/local/session_navigation_controller.dart';

import '../viewed_gifs_screen.dart';
import '../share_gif_screen.dart';
import '../collections_screen.dart';
import '../liked_gifs_screen.dart';

import 'main_screen_data_service.dart';
import 'main_screen_actions.dart';
import 'space_feed_snapshot.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
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
  SessionNavigationController? _navigationController;
  String? _lastSpaceId;
  bool _initialSpaceRestoreStarted = false;
  int _spaceRestoreGeneration = 0;
  int _fetchRequestGeneration = 0;
  String? _pendingFetchSpaceId;
  Timer? _spaceStateSaveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Flush the latest feed/search/scroll snapshot before Android may suspend
      // or terminate the process. Navigation tabs themselves are saved eagerly.
      _spaceStateSaveTimer?.cancel();
      unawaited(_persistSpaceState(_lastSpaceId));
      unawaited(
        Provider.of<ShareQueueProvider>(context, listen: false)
            .flushPersistence(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigation = Provider.of<SessionNavigationController>(
      context,
      listen: false,
    );
    if (_navigationController != navigation) {
      _navigationController?.removeListener(_onNavigationChanged);
      _navigationController = navigation;
      navigation.addListener(_onNavigationChanged);
    }
    if (!_initialSpaceRestoreStarted && navigation.isLoaded) {
      _initialSpaceRestoreStarted = true;
      _lastSpaceId = navigation.activeSpaceId;
      unawaited(_restoreSpaceState(_lastSpaceId));
    }
  }

  void _onNavigationChanged() {
    final navigation = _navigationController;
    if (navigation == null || !navigation.isLoaded) return;
    final nextSpaceId = navigation.activeSpaceId;
    if (nextSpaceId == _lastSpaceId) return;

    final previousSpaceId = _lastSpaceId;
    _lastSpaceId = nextSpaceId;
    _initialSpaceRestoreStarted = true;
    _spaceStateSaveTimer?.cancel();
    unawaited(_persistSpaceState(previousSpaceId));
    unawaited(_restoreSpaceState(nextSpaceId));
  }

  Future<void> _restoreSpaceState(String? spaceId) async {
    final navigation = _navigationController;
    if (spaceId == null || navigation == null) return;

    final generation = ++_spaceRestoreGeneration;
    final space = await navigation.repository.getSpace(spaceId);
    if (!mounted ||
        generation != _spaceRestoreGeneration ||
        navigation.activeSpaceId != spaceId) {
      return;
    }

    final snapshot = SpaceFeedSnapshot.restore(
      feedStateJson: space?.feedStateJson,
      persistedSearchQuery: space?.searchQuery,
      persistedScrollOffset: space?.scrollOffset,
      persistedPage: space?.feedPage,
    );
    if (!mounted ||
        generation != _spaceRestoreGeneration ||
        navigation.activeSpaceId != spaceId) {
      return;
    }

    setState(() {
      _mediaItems
        ..clear()
        ..addAll(snapshot.mediaItems);
      _currentPage = snapshot.currentPage;
      _totalPages = snapshot.totalPages;
      _visitedPages = snapshot.visitedPages;
      final query = snapshot.searchQuery;
      _searchController.text = query;
      _filteredItems
        ..clear()
        ..addAll(
          query.isEmpty
              ? _mediaItems
              : _mediaItems.where(
                  (item) =>
                      item.title?.toLowerCase().contains(query.toLowerCase()) ??
                      false,
                ),
        );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _spaceRestoreGeneration ||
          navigation.activeSpaceId != spaceId ||
          !_scrollController.hasClients) {
        return;
      }
      final maxOffset = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(
        snapshot.scrollOffset.clamp(0, maxOffset).toDouble(),
      );
    });

    if (snapshot.requiresFetch &&
        generation == _spaceRestoreGeneration &&
        navigation.activeSpaceId == spaceId) {
      await _fetchData(expectedSpaceId: spaceId);
    }
  }

  Future<void> _persistSpaceState(String? spaceId) async {
    final navigation = _navigationController;
    if (spaceId == null || navigation == null) return;
    final state = jsonEncode({
      'mediaItems': _mediaItems.take(120).map((item) => item.toMap()).toList(),
      'currentPage': _currentPage,
      'totalPages': _totalPages,
      'visitedPages': (_visitedPages ?? <int>{}).toList(),
      'searchQuery': _searchController.text,
      'scrollOffset': _scrollController.hasClients ? _scrollController.offset : 0,
    });
    try {
      await navigation.repository.updateSpace(
        id: spaceId,
        feedPage: _currentPage,
        feedStateJson: state,
        searchQuery: _searchController.text,
        scrollOffset: _scrollController.hasClients ? _scrollController.offset : 0,
      );
    } catch (error) {
      debugPrint('Could not persist feed state for Space $spaceId: $error');
    }
  }

  void _scheduleSpaceStateSave() {
    _spaceStateSaveTimer?.cancel();
    _spaceStateSaveTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_persistSpaceState(_lastSpaceId)),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scheduleSpaceStateSave();
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        !_hasError &&
        (_totalPages == 0 || _currentPage <= _totalPages)) {
      _fetchData();
    }
  }

  Future<void> _fetchData({String? expectedSpaceId}) async {
    if (_isLoading) {
      if (expectedSpaceId != null) _pendingFetchSpaceId = expectedSpaceId;
      return;
    }
    final requestSpaceId = expectedSpaceId ?? _lastSpaceId;
    final requestGeneration = _spaceRestoreGeneration;
    final fetchRequestId = ++_fetchRequestGeneration;
    final requestQuery = _searchController.text;
    final requestSearchController = TextEditingController(text: requestQuery);

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final result = await MainScreenDataService.fetchData(
        currentPage: _currentPage,
        mediaItems: List<MediaItem>.from(_mediaItems),
        filteredItems: List<MediaItem>.from(_filteredItems),
        searchController: requestSearchController,
        visitedPages: _visitedPages == null ? null : Set<int>.from(_visitedPages!),
        totalPages: _totalPages,
      );
      if (!mounted ||
          requestGeneration != _spaceRestoreGeneration ||
          (requestSpaceId != null &&
              _navigationController?.activeSpaceId != requestSpaceId)) {
        return;
      }
      
      setState(() {
        _mediaItems.clear();
        _mediaItems.addAll(result['mediaItems']);
        _filteredItems.clear();
        final activeQuery = _searchController.text.trim().toLowerCase();
        _filteredItems.addAll(
          activeQuery.isEmpty
              ? _mediaItems
              : _mediaItems.where(
                  (item) => item.title?.toLowerCase().contains(activeQuery) ?? false,
                ),
        );
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
        
      });
      // Persist newly fetched media even when the feed has not been scrolled yet.
      _scheduleSpaceStateSave();
    } catch (e) {
      if (mounted &&
          requestGeneration == _spaceRestoreGeneration &&
          (requestSpaceId == null ||
              _navigationController?.activeSpaceId == requestSpaceId)) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error fetching data: $e';
        });
      }
    } finally {
      requestSearchController.dispose();
      if (mounted && fetchRequestId == _fetchRequestGeneration) {
        setState(() => _isLoading = false);
        final pendingSpaceId = _pendingFetchSpaceId;
        _pendingFetchSpaceId = null;
        if (pendingSpaceId != null &&
            pendingSpaceId == _navigationController?.activeSpaceId) {
          unawaited(_fetchData(expectedSpaceId: pendingSpaceId));
        }
      }
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
    _scheduleSpaceStateSave();
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
                      } else if (value == 'collections') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CollectionsScreen()),
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
                          value: 'collections',
                          child: ListTile(
                            leading: Icon(Icons.collections_bookmark_outlined),
                            title: Text('Collections'),
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
      floatingActionButton: const GlobalShareFab(),
      bottomNavigationBar: const SessionTabBottomBar(),
      body: Column(
        children: [
          const SessionNavigationStrip(),
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
              child: Consumer<SessionNavigationController>(
                builder: (context, navigation, _) {
                  final activeTab = navigation.activeDetailTab;
                  if (activeTab != null) {
                    return DetailTabContent(
                      tab: activeTab,
                      onMoreOptions: activeTab.thumbnailUrl?.isNotEmpty == true
                          ? () => MainScreenActions.showGifDetailsDialog(
                                context,
                                MediaItem(
                                  imageUrl: activeTab.thumbnailUrl!,
                                  title: activeTab.title,
                                  href: activeTab.canonicalUrl,
                                ),
                              )
                          : null,
                    );
                  }
                  return _filteredItems.isEmpty && !_isLoading
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
    WidgetsBinding.instance.removeObserver(this);
    _spaceStateSaveTimer?.cancel();
    unawaited(_persistSpaceState(_lastSpaceId));
    _navigationController?.removeListener(_onNavigationChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}


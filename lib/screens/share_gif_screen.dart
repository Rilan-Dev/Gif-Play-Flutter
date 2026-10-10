import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../common/models/gif_item.dart';
import '../common/providers/liked_gifs_provider.dart';
import '../common/utils/file_utils.dart';
import '../common/utils/download_and_share.dart';
import '../common/utils/time_ago_util.dart';
import '../common/widgets/shimmer_loading.dart';
import '../common/widgets/global_share_fab.dart';
import 'gif_viewer_screen.dart';

// Define ActionMode class at the top level
class ActionMode {
  final Set<int> selectedItems;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  ActionMode({
    required this.selectedItems,
    required this.onClose,
    required this.onShare,
    required this.onDelete,
    required this.onSave,
  });
}

class ShareGifScreen extends StatefulWidget {
  const ShareGifScreen({Key? key}) : super(key: key);

  @override
  _ShareGifScreenState createState() => _ShareGifScreenState();
}

class _ShareGifScreenState extends State<ShareGifScreen> with SingleTickerProviderStateMixin {
  final List<GifItem> _gifItems = [];
  bool _isLoading = true;
  Set<int> _selectedItems = {};
  ActionMode? _actionMode;
  final DownloadAndShare _downloadAndShareGif = DownloadAndShare();
  bool _hasError = false;
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadSavedGifs();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedGifs() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final List<File> files = await FileUtils.getFilesInHiddenFolder();
      
      setState(() {
        _gifItems.clear();
        for (final file in files) {
          final fileName = path.basename(file.path);
          // Only include files that start with "saved_"
          if (fileName.startsWith('saved_')) {
            debugPrint('Found saved GIF: ${file.path}');
            _gifItems.add(GifItem(
              id: file.path.hashCode.toString(),
              url: file.path,
              title: fileName.replaceFirst('saved_', ''),
              imageUrl: file.path,
              altText: fileName.replaceFirst('saved_', ''),
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                file.lastModifiedSync().millisecondsSinceEpoch
              ),
            ));
          }
        }
        
        // Sort by timestamp (newest first)
        _gifItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    } catch (e) {
      debugPrint('Error loading saved GIFs: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading saved GIFs: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _enableActionMode(int index) {
    setState(() {
      _actionMode = ActionMode(
        selectedItems: {},
        onClose: () {
          setState(() {
            _actionMode = null;
            _selectedItems = {};
          });
        },
        onShare: () {
          _shareSelectedGifs();
        },
        onDelete: () {
          _deleteSelectedGifs();
        },
        onSave: () {
          _saveSelectedGifs();
        },
      );
      _toggleSelection(index);
    });
    _animationController.forward();
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
      } else {
        _selectedItems.add(index);
      }

      if (_selectedItems.isEmpty && _actionMode != null) {
        _actionMode!.onClose();
        _animationController.reverse();
      }
    });
  }

  void _shareSelectedGifs() {
    final selectedGifs = _selectedItems
        .map((index) => _gifItems[index])
        .toList();
    
    _downloadAndShareGif.downloadAndShareGifs(context, selectedGifs, true);
    
    setState(() {
      _actionMode = null;
      _selectedItems = {};
    });
    _animationController.reverse();
  }

  void _deleteSelectedGifs() {
    final selectedIndices = List<int>.from(_selectedItems);
    selectedIndices.sort((a, b) => b.compareTo(a)); // Sort in descending order

    for (final index in selectedIndices) {
      final gifItem = _gifItems[index];
      if (gifItem.url != null) {
        final file = File(gifItem.url!);
        FileUtils.deleteFile(file);
      }
      _gifItems.removeAt(index);
    }

    setState(() {
      _actionMode = null;
      _selectedItems = {};
    });
    _animationController.reverse();
  }

  void _saveSelectedGifs() {
    // TODO: Implement save functionality
    print('Save selected GIFs');
    setState(() {
      _actionMode = null;
      _selectedItems = {};
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved GIFs'),
        actions: _actionMode != null
            ? [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _actionMode!.onShare,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadSavedGifs,
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: ShimmerLoading(height: 200))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load saved GIFs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: _loadSavedGifs,
                      ),
                    ],
                  ),
                )
              : _gifItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 64,
                            color: Theme.of(context).disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No saved GIFs',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Download some GIFs to see them here',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Consumer<LikedGifsProvider>(
                      builder: (context, likedProvider, child) {
                        // Group GIFs by time category
                        final groupedGifs = TimeAgoUtil.groupByTimeCategory<GifItem>(
                          _gifItems,
                          (gif) => gif.timestamp,
                        );
                        
                        return Stack(
                          children: [
                            ListView.builder(
                              itemCount: groupedGifs.length,
                              itemBuilder: (context, categoryIndex) {
                                final category = groupedGifs.keys.toList()[categoryIndex];
                                final items = groupedGifs[category]!;
                                
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
                                        final isLiked = likedProvider.isGifLiked(item.id ?? '');
                                        final flatIndex = _gifItems.indexOf(item);
                                        final isSelected = _selectedItems.contains(flatIndex);
                                        
                                        return Card(
                                          clipBehavior: Clip.antiAlias,
                                          elevation: isSelected ? 8 : 4,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: isSelected
                                                ? BorderSide(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    width: 3,
                                                  )
                                                : BorderSide.none,
                                          ),
                                          child: InkWell(
                                            onTap: () {
                                              if (_actionMode != null) {
                                                if (flatIndex >= 0) {
                                                  _toggleSelection(flatIndex);
                                                }
                                              } else {
                                                Navigator.push(
                                                  context,
                                                  PageRouteBuilder(
                                                    pageBuilder: (context, animation, secondaryAnimation) => GifViewerScreen(
                                                      gifItems: items,
                                                      initialIndex: index,
                                                    ),
                                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                      return FadeTransition(
                                                        opacity: animation,
                                                        child: child,
                                                      );
                                                    },
                                                  ),
                                                );
                                              }
                                            },
                                            onLongPress: () {
                                              if (flatIndex >= 0) {
                                                _enableActionMode(flatIndex);
                                              }
                                            },
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                // GIF image
                                                Image.file(
                                                  File(item.url!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Center(
                                                      child: Icon(Icons.error, color: Colors.red),
                                                    );
                                                  },
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
                                                        item.title,
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
                                                        TimeAgoUtil.formatDetailed(item.timestamp),
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
                                                      onTap: () => likedProvider.toggleLikedGif(item),
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
                                                
                                                // Selection indicator
                                                if (isSelected)
                                                  Positioned(
                                                    top: 8,
                                                    left: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 20,
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
                            ),
                            
                            // Action mode bottom bar
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Transform.translate(
                                    offset: Offset(0, 100 * (1 - _animation.value)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, -2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${_selectedItems.length} selected',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: _actionMode?.onDelete,
                                                tooltip: 'Delete',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.download),
                                                onPressed: _actionMode?.onSave,
                                                tooltip: 'Save',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.share),
                                                onPressed: _actionMode?.onShare,
                                                tooltip: 'Share',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GlobalShareFab(heroTag: 'global_share_fab_saved'),
          if (_gifItems.isNotEmpty && _actionMode == null) ...[
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'saved_gifs_refresh_fab',
              onPressed: () {
                _loadSavedGifs();
              },
              child: const Icon(Icons.refresh),
            ),
          ],
        ],
      ),
    );
  }
}

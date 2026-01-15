import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../common/models/media_item.dart';
import '../common/models/gif_item.dart';
import '../common/providers/liked_gifs_provider.dart';
import '../common/utils/shared_preferences_util.dart';
import '../common/utils/time_ago_util.dart';
import '../common/utils/download_and_share.dart';
import '../common/widgets/shimmer_loading.dart';
import 'mood_vibe_screen.dart';

class ViewedGifsScreen extends StatefulWidget {
  const ViewedGifsScreen({Key? key}) : super(key: key);

  @override
  _ViewedGifsScreenState createState() => _ViewedGifsScreenState();
}

class _ViewedGifsScreenState extends State<ViewedGifsScreen> {
  List<GifItem> _viewedGifs = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final DownloadAndShare _downloadAndShareGif = DownloadAndShare();

  @override
  void initState() {
    super.initState();
    _loadViewedGifs();
  }

  void _loadViewedGifs() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      // Convert MediaItems to GifItems for consistency
      final mediaItems = SharedPreferencesUtil.getAllData();
      _viewedGifs = mediaItems.map((item) => GifItem(
        id: item.imageUrl.hashCode.toString(),
        url: item.href ?? '',
        title: item.title ?? 'No Title',
        imageUrl: item.imageUrl,
        // Use the actual timestamp from the MediaItem
        timestamp: item.timestamp ?? DateTime.now(),
      )).toList();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error loading viewed GIFs: $e';
      });
    }
  }

  Future<void> _clearViewedGifs() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear your viewed GIFs history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });
              await SharedPreferencesUtil.clearAllData();
              _loadViewedGifs();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _handleItemClick(GifItem item) {
    // Check if the item has the porngifmag.com domain
    if (item.url?.contains('porngifmag.com') == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MoodVibeScreen(
            gifLink: item.url ?? '',
            imgLink: item.imageUrl ?? '',
          ),
        ),
      );
    } else {
      // Show a dialog with options instead of just a snackbar
      _showContentOptionsDialog(item);
    }
  }

  // Update the _showContentOptionsDialog method to match the main screen implementation
  void _showContentOptionsDialog(GifItem item) {
    final likedProvider = Provider.of<LikedGifsProvider>(context, listen: false);
    final bool isLiked = likedProvider.isGifLiked(item.id ?? '');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Content Options',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            
            // Preview image - made much bigger
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl ?? item.url ?? '',
                height: 350, // Significantly increased height
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: (context, url) => const ShimmerLoading(height: 350),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            
            // First row of buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Like/Unlike button
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : null,
                    ),
                    label: Text(isLiked ? 'Unlike' : 'Like'),
                    onPressed: () {
                      likedProvider.toggleLikedGif(item);
                      Navigator.pop(context);
                    },
                  ),
                ),
                
                // Save button
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    onPressed: () {
                      // Implement save functionality
                      _downloadAndShareGif.downloadAndShareGifs(context, [item], false);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            
            // Second row of buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Share button
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () {
                      // Implement share functionality
                      _downloadAndShareGif.downloadAndShareGifs(context, [item], true);
                      Navigator.pop(context);
                    },
                  ),
                ),
                
                // Close button
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viewed GIFs'),
        actions: [
          if (_viewedGifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _clearViewedGifs,
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
                        'Failed to load viewed GIFs',
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
                        onPressed: _loadViewedGifs,
                      ),
                    ],
                  ),
                )
              : _viewedGifs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Theme.of(context).disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No viewed GIFs',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    )
                  : Consumer<LikedGifsProvider>(
                      builder: (context, likedProvider, child) {
                        // Group GIFs by time category
                        final groupedGifs = TimeAgoUtil.groupByTimeCategory<GifItem>(
                          _viewedGifs,
                          (gif) => gif.timestamp,
                        );
                        
                        return ListView.builder(
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
                                    
                                    return Card(
                                      clipBehavior: Clip.antiAlias,
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: InkWell(
                                        onTap: () => _handleItemClick(item),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // GIF image
                                            Hero(
                                              tag: 'gif_${item.id}',
                                              child: item.imageUrl != null
                                                  ? CachedNetworkImage(
                                                      imageUrl: item.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => const ShimmerLoading(height: 100),
                                                      errorWidget: (context, url, error) => const Center(
                                                        child: Icon(Icons.error, color: Colors.red),
                                                      ),
                                                    )
                                                  : const Center(child: Icon(Icons.image)),
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
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/models/gif_item.dart';
import '../common/providers/liked_gifs_provider.dart';
import '../common/utils/time_ago_util.dart';
import '../common/widgets/shimmer_loading.dart';
import 'gif_viewer_screen.dart';

class LikedGifsScreen extends StatefulWidget {
  const LikedGifsScreen({Key? key}) : super(key: key);

  @override
  _LikedGifsScreenState createState() => _LikedGifsScreenState();
}

class _LikedGifsScreenState extends State<LikedGifsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to schedule the loading after the build is complete
    Future.microtask(() => _loadLikedGifs());
  }

  Future<void> _loadLikedGifs() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // Wrap in a try-catch to handle any errors
    try {
      await Provider.of<LikedGifsProvider>(context, listen: false).loadLikedGifs();
    } catch (e) {
      debugPrint('Error loading liked GIFs: $e');
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLikedGifs() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Liked GIFs'),
        content: const Text('Are you sure you want to clear all your liked GIFs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<LikedGifsProvider>(context, listen: false).clearLikedGifs();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked GIFs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLikedGifs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLikedGifs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: ShimmerLoading(height: 200))
          : Consumer<LikedGifsProvider>(
              builder: (context, provider, child) {
                final likedGifs = provider.likedGifs;
                
                if (likedGifs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No liked GIFs',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Like some GIFs to see them here',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                // Group GIFs by time category
                final groupedGifs = TimeAgoUtil.groupByTimeCategory<GifItem>(
                  likedGifs,
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
                            
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () {
                                  // Find the overall index in the flat list
                                  final flatList = likedGifs;
                                  final overallIndex = flatList.indexOf(item);
                                  
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => GifViewerScreen(
                                        gifItems: flatList,
                                        initialIndex: overallIndex >= 0 ? overallIndex : 0,
                                      ),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // GIF image
                                    Hero(
                                      tag: 'gif_${item.id}',
                                      child: item.imageUrl != null
                                          ? Image.network(
                                              item.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Center(
                                                  child: Icon(Icons.error, color: Colors.red),
                                                );
                                              },
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
                                          onTap: () => provider.toggleLikedGif(item),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.favorite,
                                              color: Colors.red,
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


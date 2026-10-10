import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../common/models/gif_item.dart';
import '../common/providers/viewed_gifs_provider.dart';
import '../services/gif_service.dart';
import '../common/widgets/cached_gif.dart';
import '../common/providers/liked_gifs_provider.dart';
import '../common/providers/share_queue_provider.dart';
import '../common/widgets/global_share_fab.dart';

class GifDetailScreen extends StatefulWidget {
  final GifItem gif;

  const GifDetailScreen({
    Key? key,
    required this.gif,
  }) : super(key: key);

  @override
  State<GifDetailScreen> createState() => _GifDetailScreenState();
}

class _GifDetailScreenState extends State<GifDetailScreen> {
  final GifService _gifService = GifService();
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    // Mark as viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Provider.of<ViewedGifsProvider>(context, listen: false)
            .addViewedGif(widget.gif);
      }
    });
  }

  Future<void> _shareGif() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      await _gifService.downloadAndShareGif(widget.gif);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share GIF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gif.title),
        actions: [
          Consumer<LikedGifsProvider>(
            builder: (context, likedProvider, child) {
              final isLiked = likedProvider.isGifLiked(widget.gif.id ?? '');
              return IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : null,
                ),
                onPressed: () {
                  likedProvider.toggleLikedGif(widget.gif);
                },
              );
            },
          ),
          Consumer<ShareQueueProvider>(
            builder: (context, shareQueue, child) {
              final isCollected = shareQueue.contains(widget.gif);
              return IconButton(
                icon: Icon(
                  isCollected ? Icons.playlist_add_check : Icons.playlist_add,
                ),
                onPressed: () {
                  if (isCollected) {
                    shareQueue.removeGif(widget.gif);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from share list')),
                    );
                  } else {
                    shareQueue.addGif(widget.gif);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to share list')),
                    );
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isDownloading ? null : _shareGif,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: CachedGif(
                      url: widget.gif.url ?? '',
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                  // Add like button overlay
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Consumer<LikedGifsProvider>(
                      builder: (context, likedProvider, child) {
                        final isLiked = likedProvider.isGifLiked(widget.gif.id ?? '');
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              likedProvider.toggleLikedGif(widget.gif);
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_isDownloading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      floatingActionButton: const GlobalShareFab(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/models/gif_item.dart';
import '../common/providers/viewed_gifs_provider.dart';
import '../services/gif_service.dart';
import 'mood_vibe_screen.dart';
import 'search_screen.dart';
import 'viewed_gifs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GifService _gifService = GifService();
  List<GifItem> _trendingGifs = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 0;
  static const int _itemsPerPage = 25;

  @override
  void initState() {
    super.initState();
    _loadTrendingGifs();
  }

  Future<void> _loadTrendingGifs({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 0;
        _isLoading = true;
        _hasError = false;
      });
    } else if (_isLoading) {
      return;
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final gifs = await _gifService.getTrendingGifs(
        limit: _itemsPerPage,
        offset: _currentPage * _itemsPerPage,
      );
      
      setState(() {
        if (refresh || _currentPage == 0) {
          _trendingGifs = gifs;
        } else {
          _trendingGifs.addAll(gifs);
        }
        _isLoading = false;
        _currentPage++;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GIF Play'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ViewedGifsScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MoodVibeScreen(
                gifLink: 'https://example.com/gif',
                imgLink: 'https://example.com/img',
              ),
            ),
          );
        },
        child: const Icon(Icons.mood),
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Failed to load GIFs'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadTrendingGifs(refresh: true),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTrendingGifs(refresh: true),
      child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _trendingGifs.length,
              itemBuilder: (context, index) {
                final gif = _trendingGifs[index];
                return ListTile(
                  title: Text(gif.title),
                  leading: gif.imageUrl != null 
                      ? Image.network(
                          gif.imageUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.error),
                        )
                      : const Icon(Icons.image),
                  onTap: () {
                    // Mark gif as viewed
                    Provider.of<ViewedGifsProvider>(context, listen: false).addViewedGif(gif);
                    
                    // Navigate to gif detail screen
                    Navigator.pushNamed(context, '/gif-detail', arguments: gif);
                  },
                  onLongPress: () {
                    // Handle long press
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Long pressed: ${gif.title}')),
                    );
                  },
                );
              },
            ),
    );
  }
}


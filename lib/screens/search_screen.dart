import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/models/gif_item.dart';
import '../common/providers/viewed_gifs_provider.dart';
import '../services/gif_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GifService _gifService = GifService();
  List<GifItem> _searchResults = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _currentQuery = '';
  int _currentPage = 0;
  static const int _itemsPerPage = 25;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch({bool newSearch = false}) async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      return;
    }

    if (newSearch) {
      setState(() {
        _currentQuery = query;
        _currentPage = 0;
        _searchResults = [];
        _isLoading = true;
        _hasError = false;
      });
    } else if (_isLoading || query != _currentQuery) {
      return;
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final results = await _gifService.searchGifs(
        query,
        limit: _itemsPerPage,
        offset: _currentPage * _itemsPerPage,
      );
      
      setState(() {
        if (newSearch || _currentPage == 0) {
          _searchResults = results;
        } else {
          _searchResults.addAll(results);
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
        title: const Text('Search GIFs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for GIFs...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(newSearch: true),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searchResults.isEmpty && !_isLoading && !_hasError) {
      return const Center(
        child: Text('Search for GIFs to get started'),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Failed to load search results'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _performSearch(newSearch: true),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final gif = _searchResults[index];
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
    );
  }
}


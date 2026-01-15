import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/gif_item.dart';
import '../utils/shared_preferences_util.dart';

/// Provider for managing viewed GIFs.
///
/// This class provides methods for getting, adding, and removing viewed GIFs,
/// with support for persistence using SharedPreferences.
class ViewedGifsProvider with ChangeNotifier {
  final List<GifItem> _viewedGifs = [];
  static const String _viewedGifsKey = 'viewed_gifs';
  static const int _maxViewedGifs = 100;

  ViewedGifsProvider();

  /// Get the list of viewed GIFs.
  List<GifItem> get viewedGifs => List.unmodifiable(_viewedGifs);

  /// Load viewed GIFs from SharedPreferences.
  Future<void> loadViewedGifs() async {
    final jsonString = SharedPreferencesUtil.getString(_viewedGifsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        _viewedGifs.clear();
        _viewedGifs.addAll(
          jsonList.map((item) => GifItem.fromMap(item)).toList(),
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading viewed gifs: $e');
      }
    }
  }

  /// Add a GIF to the viewed GIFs list.
  Future<void> addViewedGif(GifItem gif) async {
    // Check if gif is already in the list
    final existingIndex = _viewedGifs.indexWhere((item) => item.id == gif.id);
    
    if (existingIndex >= 0) {
      // Update existing gif
      _viewedGifs[existingIndex] = gif.copyWith(isViewed: true);
    } else {
      // Add new gif
      _viewedGifs.add(gif.copyWith(isViewed: true));
      
      // Limit the number of viewed gifs
      if (_viewedGifs.length > _maxViewedGifs) {
        _viewedGifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _viewedGifs.removeRange(_maxViewedGifs, _viewedGifs.length);
      }
    }
    
    notifyListeners();
    await _saveViewedGifs();
  }

  /// Clear all viewed GIFs.
  Future<void> clearViewedGifs() async {
    _viewedGifs.clear();
    notifyListeners();
    await _saveViewedGifs();
  }

  /// Check if a GIF has been viewed.
  bool isGifViewed(String gifId) {
    return _viewedGifs.any((gif) => gif.id == gifId);
  }

  /// Save viewed GIFs to SharedPreferences.
  Future<void> _saveViewedGifs() async {
    final jsonList = _viewedGifs.map((gif) => gif.toMap()).toList();
    final jsonString = json.encode(jsonList);
    await SharedPreferencesUtil.setString(_viewedGifsKey, jsonString);
  }
}


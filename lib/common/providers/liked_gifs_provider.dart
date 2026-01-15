import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/gif_item.dart';
import '../utils/shared_preferences_util.dart';

/// Provider for managing liked GIFs.
///
/// This class provides methods for getting, adding, and removing liked GIFs,
/// with support for persistence using SharedPreferences.
class LikedGifsProvider with ChangeNotifier {
  final List<GifItem> _likedGifs = [];
  static const String _likedGifsKey = 'liked_gifs';
  static const int _maxLikedGifs = 500;

  LikedGifsProvider();

  /// Get the list of liked GIFs.
  List<GifItem> get likedGifs => List.unmodifiable(_likedGifs);

  /// Load liked GIFs from SharedPreferences.
  Future<void> loadLikedGifs() async {
    final jsonString = SharedPreferencesUtil.getString(_likedGifsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        
        // Create a temporary list to avoid modifying _likedGifs directly
        final tempList = jsonList.map((item) => GifItem.fromMap(item)).toList();
        
        // Update the list and notify listeners in a single operation
        _likedGifs.clear();
        _likedGifs.addAll(tempList);
        
        // Use Future.microtask to schedule notification after the current build phase
        Future.microtask(() => notifyListeners());
      } catch (e) {
        debugPrint('Error loading liked gifs: $e');
      }
    }
  }

  /// Toggle the liked status of a GIF.
  Future<void> toggleLikedGif(GifItem gif) async {
    // Check if gif is already in the list
    final existingIndex = _likedGifs.indexWhere((item) => item.id == gif.id);

    if (existingIndex >= 0) {
      // Remove existing gif
      _likedGifs.removeAt(existingIndex);
    } else {
      // Add new gif with current timestamp
      _likedGifs.add(gif.copyWith(
        timestamp: DateTime.now(),
      ));
      
      // Limit the number of liked gifs
      if (_likedGifs.length > _maxLikedGifs) {
        _likedGifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _likedGifs.removeRange(_maxLikedGifs, _likedGifs.length);
      }
    }

    notifyListeners();
    await _saveLikedGifs();
  }

  /// Check if a GIF is liked.
  bool isGifLiked(String? gifId) {
    if (gifId == null) return false;
    return _likedGifs.any((gif) => gif.id == gifId);
  }

  /// Clear all liked GIFs.
  Future<void> clearLikedGifs() async {
    _likedGifs.clear();
    notifyListeners();
    await _saveLikedGifs();
  }

  /// Save liked GIFs to SharedPreferences.
  Future<void> _saveLikedGifs() async {
    final jsonList = _likedGifs.map((gif) => gif.toMap()).toList();
    final jsonString = json.encode(jsonList);
    await SharedPreferencesUtil.setString(_likedGifsKey, jsonString);
  }
}


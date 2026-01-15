import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

/// Utility class for working with SharedPreferences.
///
/// This class provides methods for storing and retrieving data from SharedPreferences,
/// with support for various data types and operations.
class SharedPreferencesUtil {
  static late SharedPreferences _staticPrefs;

  /// Initialize the SharedPreferences instance.
  static void init(SharedPreferences prefs) {
    _staticPrefs = prefs;
  }

  /// Store a viewed GIF
  static Future<bool> storeContact(String imageUrl, String href, {String? title}) async {
    try {
      // Create a key for this specific item
      String key = 'viewed_gif_${imageUrl.hashCode}';
      
      // Get current timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Check if this specific item already exists
      if (_staticPrefs.containsKey(key)) {
        // Update the timestamp to current time
        final String? existingData = _staticPrefs.getString(key);
        if (existingData != null) {
          try {
            Map<String, dynamic> data = json.decode(existingData);
            data['timestamp'] = timestamp; // Update timestamp
            await _staticPrefs.setString(key, json.encode(data));
          } catch (e) {
            debugPrint('Error updating timestamp: $e');
          }
        }
        return true; // Item exists and was updated
      }
      
      // Store as a simple string (JSON)
      Map<String, dynamic> data = {
        'imageUrl': imageUrl,
        'title': title ?? '',
        'href': href,
        'timestamp': timestamp,
      };
      
      String jsonData = json.encode(data);
      bool success = await _staticPrefs.setString(key, jsonData);
      
      // Also maintain a list of keys for easy retrieval
      List<String> allKeys = _staticPrefs.getStringList('viewed_gif_keys') ?? [];
      if (!allKeys.contains(key)) {
        allKeys.add(key);
        await _staticPrefs.setStringList('viewed_gif_keys', allKeys);
      }
      
      return success;
    } catch (e) {
      debugPrint('Error storing contact: $e');
      return false;
    }
  }

  /// Check if data exists
  static bool isDataExists(String imageUrl) {
    try {
      String key = 'viewed_gif_${imageUrl.hashCode}';
      return _staticPrefs.containsKey(key);
    } catch (e) {
      debugPrint('Error in isDataExists: $e');
      return false;
    }
  }

  /// Get all viewed GIFs
  static List<MediaItem> getAllData() {
    try {
      List<String> allKeys = _staticPrefs.getStringList('viewed_gif_keys') ?? [];
      List<MediaItem> items = [];
      
      for (String key in allKeys) {
        String? jsonData = _staticPrefs.getString(key);
        if (jsonData != null) {
          try {
            Map<String, dynamic> data = json.decode(jsonData);
            items.add(MediaItem(
              imageUrl: data['imageUrl'] ?? '',
              title: data['title'],
              href: data['href'],
              timestamp: data['timestamp'] != null 
                  ? DateTime.fromMillisecondsSinceEpoch(data['timestamp']) 
                  : DateTime.now(),
            ));
          } catch (e) {
            debugPrint('Error parsing JSON for key $key: $e');
          }
        }
      }
      
      return items;
    } catch (e) {
      debugPrint('Error in getAllData: $e');
      return [];
    }
  }

  /// Clear all viewed GIFs
  static Future<bool> clearAllData() async {
    try {
      List<String> allKeys = _staticPrefs.getStringList('viewed_gif_keys') ?? [];
      
      // Remove all individual entries
      for (String key in allKeys) {
        await _staticPrefs.remove(key);
      }
      
      // Clear the keys list
      return await _staticPrefs.remove('viewed_gif_keys');
    } catch (e) {
      debugPrint('Error in clearAllData: $e');
      return false;
    }
  }

  // String methods
  static String? getString(String key) => _staticPrefs.getString(key);

  static Future<bool> setString(String key, String value) => 
      _staticPrefs.setString(key, value);

  // Boolean methods
  static bool getBool(String key, {bool defaultValue = false}) => 
      _staticPrefs.getBool(key) ?? defaultValue;

  static Future<bool> setBool(String key, bool value) => 
      _staticPrefs.setBool(key, value);

  // Integer methods
  static int getInt(String key, {int defaultValue = 0}) => 
      _staticPrefs.getInt(key) ?? defaultValue;

  static Future<bool> setInt(String key, int value) => 
      _staticPrefs.setInt(key, value);

  // Double methods
  static double getDouble(String key, {double defaultValue = 0.0}) => 
      _staticPrefs.getDouble(key) ?? defaultValue;

  static Future<bool> setDouble(String key, double value) => 
      _staticPrefs.setDouble(key, value);

  // List methods
  static List<String> getStringList(String key, {List<String> defaultValue = const []}) => 
      _staticPrefs.getStringList(key) ?? defaultValue;

  static Future<bool> setStringList(String key, List<String> value) => 
      _staticPrefs.setStringList(key, value);

  // Remove and clear methods
  static Future<bool> remove(String key) => _staticPrefs.remove(key);

  static Future<bool> clear() => _staticPrefs.clear();

  static bool containsKey(String key) => _staticPrefs.containsKey(key);
}


import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/gif_item.dart';
import '../utils/shared_preferences_util.dart';

/// In-memory staging queue for GIFs the user plans to share.
class ShareQueueProvider with ChangeNotifier {
  static const int maxQueuedGifs = 200;
  static const String _storageKey = 'share_queue_gifs_v1';
  final List<GifItem> _queuedGifs = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Restores the durable share list before the first screen is displayed.
  Future<void> loadQueuedGifs() async {
    try {
      final encoded = SharedPreferencesUtil.getString(_storageKey);
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          final restored = <GifItem>[];
          final seen = <String>{};
          for (final value in decoded) {
            if (value is! Map) continue;
            try {
              final gif = _normalize(
                GifItem.fromMap(Map<String, dynamic>.from(value)),
              );
              final key = keyFor(gif);
              if (seen.add(key)) restored.add(gif);
              if (restored.length >= maxQueuedGifs) break;
            } catch (error) {
              debugPrint('Skipping invalid saved share-queue item: $error');
            }
          }
          _queuedGifs
            ..clear()
            ..addAll(restored);
        }
      }
    } catch (error) {
      debugPrint('Could not restore saved share queue: $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Waits for the current queue snapshot to be written to local storage.
  /// Useful before an intentional app-level navigation or lifecycle handoff.
  Future<void> flushPersistence() => _persistQueue();

  Future<void> _persistQueue() async {
    try {
      await SharedPreferencesUtil.setString(
        _storageKey,
        jsonEncode(_queuedGifs.map((gif) => gif.toMap()).toList()),
      );
    } catch (error) {
      debugPrint('Could not persist share queue: $error');
    }
  }

  List<GifItem> get queuedGifs => List.unmodifiable(_queuedGifs);
  int get count => _queuedGifs.length;

  String keyFor(GifItem gif) {
    final id = gif.id?.trim();
    if (id != null && id.isNotEmpty) return id;
    final url = gif.url?.trim();
    if (url != null && url.isNotEmpty) return 'url:$url';
    final imageUrl = gif.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) return 'img:$imageUrl';
    return 'title:${gif.title}';
  }

  GifItem _normalize(GifItem gif) {
    final key = keyFor(gif);
    final imageUrl = gif.imageUrl?.trim().isNotEmpty == true
        ? gif.imageUrl
        : gif.url;
    return gif.copyWith(
      id: gif.id?.trim().isNotEmpty == true ? gif.id : key,
      imageUrl: imageUrl,
    );
  }

  bool contains(GifItem gif) {
    final key = keyFor(gif);
    return _queuedGifs.any((item) => keyFor(item) == key);
  }

  void addGif(GifItem gif) {
    final normalized = _normalize(gif);
    final key = keyFor(normalized);
    _queuedGifs.removeWhere((item) => keyFor(item) == key);
    _queuedGifs.insert(0, normalized.copyWith(timestamp: DateTime.now()));
    if (_queuedGifs.length > maxQueuedGifs) {
      _queuedGifs.removeRange(maxQueuedGifs, _queuedGifs.length);
    }
    notifyListeners();
    unawaited(_persistQueue());
  }

  void addGifs(Iterable<GifItem> gifs) {
    final normalized = gifs.map(_normalize).toList(growable: false);
    if (normalized.isEmpty) return;
    for (final gif in normalized.reversed) {
      final key = keyFor(gif);
      _queuedGifs.removeWhere((item) => keyFor(item) == key);
      _queuedGifs.insert(0, gif.copyWith(timestamp: DateTime.now()));
    }
    if (_queuedGifs.length > maxQueuedGifs) {
      _queuedGifs.removeRange(maxQueuedGifs, _queuedGifs.length);
    }
    notifyListeners();
    unawaited(_persistQueue());
  }

  bool removeGif(GifItem gif) {
    final key = keyFor(gif);
    final previousLength = _queuedGifs.length;
    _queuedGifs.removeWhere((item) => keyFor(item) == key);
    if (_queuedGifs.length == previousLength) return false;
    notifyListeners();
    unawaited(_persistQueue());
    return true;
  }

  void removeGifs(Iterable<GifItem> gifs) {
    final keys = gifs.map(keyFor).toSet();
    if (keys.isEmpty) return;
    final previousLength = _queuedGifs.length;
    _queuedGifs.removeWhere((item) => keys.contains(keyFor(item)));
    if (_queuedGifs.length != previousLength) {
      notifyListeners();
      unawaited(_persistQueue());
    }
  }

  void clear() {
    if (_queuedGifs.isEmpty) return;
    _queuedGifs.clear();
    notifyListeners();
    unawaited(_persistQueue());
  }
}

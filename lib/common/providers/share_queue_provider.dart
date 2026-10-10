import 'package:flutter/foundation.dart';

import '../models/gif_item.dart';

/// In-memory staging queue for GIFs the user plans to share.
class ShareQueueProvider with ChangeNotifier {
  static const int maxQueuedGifs = 200;
  final List<GifItem> _queuedGifs = [];

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
  }

  bool removeGif(GifItem gif) {
    final key = keyFor(gif);
    final previousLength = _queuedGifs.length;
    _queuedGifs.removeWhere((item) => keyFor(item) == key);
    if (_queuedGifs.length == previousLength) return false;
    notifyListeners();
    return true;
  }

  void removeGifs(Iterable<GifItem> gifs) {
    final keys = gifs.map(keyFor).toSet();
    if (keys.isEmpty) return;
    final previousLength = _queuedGifs.length;
    _queuedGifs.removeWhere((item) => keys.contains(keyFor(item)));
    if (_queuedGifs.length != previousLength) notifyListeners();
  }

  void clear() {
    if (_queuedGifs.isEmpty) return;
    _queuedGifs.clear();
    notifyListeners();
  }
}

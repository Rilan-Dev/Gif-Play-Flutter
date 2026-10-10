import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/gif_item.dart';
import '../utils/file_utils.dart';

/// Provider for managing the global share queue.
///
/// This keeps a list of GIFs that the user wants to share later.
class ShareQueueProvider with ChangeNotifier {
  final List<GifItem> _queuedGifs = [];
  final Set<String> _prefetchingKeys = {};
  static const int _maxQueuedGifs = 200;

  List<GifItem> get queuedGifs => List.unmodifiable(_queuedGifs);
  int get count => _queuedGifs.length;

  String keyFor(GifItem gif) {
    return _stableKey(gif);
  }

  String _stableKey(GifItem gif) {
    final id = gif.id?.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final url = gif.url?.trim();
    if (url != null && url.isNotEmpty) {
      return 'url:$url';
    }
    final imageUrl = gif.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return 'img:$imageUrl';
    }
    return 'title:${gif.title}';
  }

  GifItem _normalizeGif(GifItem gif) {
    final stableKey = _stableKey(gif);
    final imageUrl = (gif.imageUrl != null && gif.imageUrl!.trim().isNotEmpty)
        ? gif.imageUrl
        : gif.url;
    return gif.copyWith(
      id: gif.id?.trim().isNotEmpty == true ? gif.id : stableKey,
      imageUrl: imageUrl,
    );
  }

  bool contains(GifItem gif) {
    final key = keyFor(gif);
    return _queuedGifs.any((item) => keyFor(item) == key);
  }

  void addGif(GifItem gif) {
    final normalized = _normalizeGif(gif);
    final key = keyFor(normalized);
    _queuedGifs.removeWhere((item) => keyFor(item) == key);
    _queuedGifs.insert(0, normalized.copyWith(timestamp: DateTime.now()));
    if (_queuedGifs.length > _maxQueuedGifs) {
      _queuedGifs.removeRange(_maxQueuedGifs, _queuedGifs.length);
    }
    notifyListeners();
    _prefetchGif(normalized);
  }

  void addGifs(Iterable<GifItem> gifs) {
    bool changed = false;
    for (final gif in gifs) {
      final normalized = _normalizeGif(gif);
      final key = keyFor(normalized);
      _queuedGifs.removeWhere((item) => keyFor(item) == key);
      _queuedGifs.insert(0, normalized.copyWith(timestamp: DateTime.now()));
      _prefetchGif(normalized);
      changed = true;
    }
    if (_queuedGifs.length > _maxQueuedGifs) {
      _queuedGifs.removeRange(_maxQueuedGifs, _queuedGifs.length);
    }
    if (changed) {
      notifyListeners();
    }
  }

  bool removeGif(GifItem gif) {
    final key = keyFor(gif);
    final beforeLength = _queuedGifs.length;
    _queuedGifs.removeWhere((item) => keyFor(item) == key);
    final removed = beforeLength != _queuedGifs.length;
    if (removed) {
      notifyListeners();
    }
    return removed;
  }

  void removeGifs(Iterable<GifItem> gifs) {
    bool changed = false;
    for (final gif in gifs) {
      final key = keyFor(gif);
      final beforeLength = _queuedGifs.length;
      _queuedGifs.removeWhere((item) => keyFor(item) == key);
      if (beforeLength != _queuedGifs.length) {
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void clear() {
    if (_queuedGifs.isEmpty) return;
    _queuedGifs.clear();
    notifyListeners();
  }

  Future<void> _prefetchGif(GifItem gif) async {
    final key = keyFor(gif);
    if (_prefetchingKeys.contains(key)) return;

    final index = _queuedGifs.indexWhere((item) => keyFor(item) == key);
    if (index < 0) return;

    final current = _queuedGifs[index];
    if (_isLocalPath(current.url) || _isLocalPath(current.imageUrl)) {
      return;
    }

    final sourceUrl = _selectSourceUrl(current);
    if (sourceUrl == null) return;

    _prefetchingKeys.add(key);
    try {
      final filePath = await _downloadToQueue(sourceUrl, key);
      if (filePath == null) return;

      final updated = current.copyWith(url: filePath);
      final updatedIndex =
          _queuedGifs.indexWhere((item) => keyFor(item) == key);
      if (updatedIndex >= 0) {
        _queuedGifs[updatedIndex] = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error prefetching GIF: $e');
    } finally {
      _prefetchingKeys.remove(key);
    }
  }

  String? _selectSourceUrl(GifItem gif) {
    final url = gif.url?.trim();
    if (url != null && url.startsWith('http')) return url;
    final imageUrl = gif.imageUrl?.trim();
    if (imageUrl != null && imageUrl.startsWith('http')) return imageUrl;
    return null;
  }

  bool _isLocalPath(String? pathValue) {
    if (pathValue == null) return false;
    return pathValue.startsWith('/');
  }

  Future<String?> _downloadToQueue(String url, String key) async {
    final hiddenFolder = await FileUtils.getHiddenFolder();
    final baseName = _safeFileName(_baseNameFromUrl(url));
    final fileName = 'queued_${key.hashCode.abs()}_$baseName';
    final filePath = path.join(hiddenFolder.path, fileName);

    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }

    final downloaded = await FileUtils.downloadFile(
      url,
      customFileName: fileName,
    );
    if (await downloaded.exists()) {
      return downloaded.path;
    }
    return null;
  }

  String _baseNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    } catch (_) {}
    return 'gif_${DateTime.now().millisecondsSinceEpoch}.gif';
  }

  String _safeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isEmpty) {
      return 'gif_${DateTime.now().millisecondsSinceEpoch}.gif';
    }
    if (!sanitized.contains('.')) {
      return '$sanitized.gif';
    }
    return sanitized;
  }
}

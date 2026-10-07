import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../data/local/local_media_repository.dart';
import '../../data/local/media_identity.dart';
import '../../data/local/models/collection.dart';
import '../../data/local/models/media_record.dart';
import '../models/gif_item.dart';
import '../utils/shared_preferences_util.dart';

class LikedGifsProvider with ChangeNotifier {
  LikedGifsProvider([this._repository]);
  final LocalMediaRepository? _repository;
  final List<GifItem> _likedGifs = [];
  static const String _likedGifsKey = 'liked_gifs';
  static const int _maxLikedGifs = 500;
  static const String _collectionId = 'bbdfa3ba3e08f524f1813368e5373a40d7a363bdd51289475aad93c37c07ae7c';

  List<GifItem> get likedGifs => List.unmodifiable(_likedGifs);

  Future<void> loadLikedGifs() async {
    if (_repository == null) { await _loadLegacy(); return; }
    final collection = await _ensureCollection();
    final records = await _repository!.listCollectionMedia(collection.id, limit: _maxLikedGifs);
    _replace(records.map(_toGifItem).toList(growable: false));
  }

  Future<void> toggleLikedGif(GifItem gif) async {
    if (_repository == null) { await _toggleLegacy(gif); return; }
    final collection = await _ensureCollection();
    final existing = _likedGifs.indexWhere((item) => _mediaId(item) == _mediaId(gif));
    if (existing >= 0) {
      await _repository!.removeFromCollection(collectionId: collection.id, mediaId: _mediaId(_likedGifs[existing]));
      _likedGifs.removeAt(existing);
    } else {
      final stamped = gif.copyWith(timestamp: DateTime.now());
      await _repository!.addToCollection(collectionId: collection.id, media: _toMediaRecord(stamped));
      _likedGifs.insert(0, stamped);
      if (_likedGifs.length > _maxLikedGifs) {
        final evicted = _likedGifs.removeLast();
        await _repository!.removeFromCollection(collectionId: collection.id, mediaId: _mediaId(evicted));
      }
    }
    notifyListeners();
  }

  bool isGifLiked(String? gifId) => gifId != null && _likedGifs.any((gif) => gif.id == gifId);

  Future<void> clearLikedGifs() async {
    if (_repository != null) {
      final collection = await _ensureCollection();
      await _repository!.clearCollectionItems(collection.id);
    } else {
      await SharedPreferencesUtil.setString(_likedGifsKey, '[]');
    }
    _likedGifs.clear();
    notifyListeners();
  }

  Future<void> _loadLegacy() async {
    final value = SharedPreferencesUtil.getString(_likedGifsKey);
    if (value == null || value.isEmpty) return;
    try {
      final decoded = json.decode(value);
      if (decoded is! List) return;
      _replace(decoded.whereType<Map>().map((item) => GifItem.fromMap(Map<String, dynamic>.from(item))).toList());
    } catch (e) { debugPrint('Error loading liked gifs: $e'); }
  }

  Future<void> _toggleLegacy(GifItem gif) async {
    final index = _likedGifs.indexWhere((item) => item.id == gif.id);
    if (index >= 0) { _likedGifs.removeAt(index); }
    else { _likedGifs.insert(0, gif.copyWith(timestamp: DateTime.now())); if (_likedGifs.length > _maxLikedGifs) _likedGifs.removeLast(); }
    notifyListeners();
    await SharedPreferencesUtil.setString(_likedGifsKey, json.encode(_likedGifs.map((item) => item.toMap()).toList()));
  }

  Future<GifCollection> _ensureCollection() async {
    final existing = await _repository!.getCollection(_collectionId);
    return existing ?? await _repository!.createCollection('Liked GIFs', id: _collectionId);
  }

  String _mediaId(GifItem gif) => gif.id ?? MediaIdentity.fromUrls(mediaUrl: (gif.imageUrl ?? gif.url ?? '').trim(), sourceUrl: gif.url);

  MediaRecord _toMediaRecord(GifItem gif) {
    final mediaUrl = (gif.imageUrl ?? gif.url ?? '').trim();
    final sourceUrl = (gif.url ?? mediaUrl).trim();
    final id = gif.id ?? MediaIdentity.fromUrls(mediaUrl: mediaUrl, sourceUrl: sourceUrl);
    return MediaRecord(id: id, sourceUrl: sourceUrl, mediaUrl: mediaUrl, thumbnailUrl: gif.previewUrl, title: gif.title, width: gif.width, height: gif.height, searchText: '${gif.title} ${gif.altText ?? ''} $sourceUrl $mediaUrl'.toLowerCase(), createdAt: gif.timestamp, updatedAt: DateTime.now(), lastSeenAt: gif.timestamp);
  }

  GifItem _toGifItem(MediaRecord media) => GifItem(id: media.id, url: media.sourceUrl, title: media.title ?? '', previewUrl: media.thumbnailUrl, timestamp: media.createdAt ?? media.updatedAt ?? DateTime.now(), imageUrl: media.mediaUrl, width: media.width, height: media.height);
  void _replace(List<GifItem> items) { _likedGifs..clear()..addAll(items.take(_maxLikedGifs)); notifyListeners(); }
}
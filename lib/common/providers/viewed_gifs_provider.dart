import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../data/local/local_media_repository.dart';
import '../../data/local/media_identity.dart';
import '../../data/local/models/collection.dart';
import '../../data/local/models/media_record.dart';
import '../models/gif_item.dart';
import '../utils/shared_preferences_util.dart';

class ViewedGifsProvider with ChangeNotifier {
  ViewedGifsProvider([this._repository]);
  final LocalMediaRepository? _repository;
  final List<GifItem> _viewedGifs = [];
  static const String _viewedGifsKey = 'viewed_gifs';
  static const int _maxViewedGifs = 100;
  static const String _collectionId = '740d3d9c3a1632d1c11826081faea5ec3446824ee4ad53dfb88d208970b579e1';

  List<GifItem> get viewedGifs => List.unmodifiable(_viewedGifs);

  Future<void> loadViewedGifs() async {
    if (_repository == null) { await _loadLegacy(); return; }
    final collection = await _ensureCollection();
    final records = await _repository!.listCollectionMedia(collection.id, limit: _maxViewedGifs);
    _replace(records.map(_toGifItem).toList(growable: false));
  }

  Future<void> addViewedGif(GifItem gif) async {
    if (_repository == null) { await _addLegacy(gif); return; }
    final collection = await _ensureCollection();
    final stamped = gif.copyWith(isViewed: true, timestamp: DateTime.now());
    await _repository!.addToCollection(collectionId: collection.id, media: _toMediaRecord(stamped));
    final existing = _viewedGifs.indexWhere((item) => _mediaId(item) == _mediaId(stamped));
    if (existing >= 0) _viewedGifs.removeAt(existing);
    _viewedGifs.insert(0, stamped);
    if (_viewedGifs.length > _maxViewedGifs) {
      final evicted = _viewedGifs.removeLast();
      await _repository!.removeFromCollection(collectionId: collection.id, mediaId: _mediaId(evicted));
    }
    notifyListeners();
  }

  Future<void> clearViewedGifs() async {
    if (_repository != null) {
      final collection = await _ensureCollection();
      await _repository!.clearCollectionItems(collection.id);
    } else { await SharedPreferencesUtil.setString(_viewedGifsKey, '[]'); }
    _viewedGifs.clear();
    notifyListeners();
  }

  bool isGifViewed(String gifId) => _viewedGifs.any((gif) => gif.id == gifId);

  Future<void> _loadLegacy() async {
    final value = SharedPreferencesUtil.getString(_viewedGifsKey);
    if (value == null || value.isEmpty) return;
    try {
      final decoded = json.decode(value);
      if (decoded is! List) return;
      _replace(decoded.whereType<Map>().map((item) => GifItem.fromMap(Map<String, dynamic>.from(item))).toList());
    } catch (e) { debugPrint('Error loading viewed gifs: $e'); }
  }

  Future<void> _addLegacy(GifItem gif) async {
    final stamped = gif.copyWith(isViewed: true, timestamp: DateTime.now());
    final existing = _viewedGifs.indexWhere((item) => item.id == stamped.id);
    if (existing >= 0) _viewedGifs.removeAt(existing);
    _viewedGifs.insert(0, stamped);
    if (_viewedGifs.length > _maxViewedGifs) _viewedGifs.removeLast();
    notifyListeners();
    await SharedPreferencesUtil.setString(_viewedGifsKey, json.encode(_viewedGifs.map((item) => item.toMap()).toList()));
  }

  Future<GifCollection> _ensureCollection() async {
    final existing = await _repository!.getCollection(_collectionId);
    return existing ?? await _repository!.createCollection('Viewed GIFs', id: _collectionId);
  }

  String _mediaId(GifItem gif) => gif.id ?? MediaIdentity.fromUrls(mediaUrl: (gif.imageUrl ?? gif.url ?? '').trim(), sourceUrl: gif.url);

  MediaRecord _toMediaRecord(GifItem gif) {
    final mediaUrl = (gif.imageUrl ?? gif.url ?? '').trim();
    final sourceUrl = (gif.url ?? mediaUrl).trim();
    final id = gif.id ?? MediaIdentity.fromUrls(mediaUrl: mediaUrl, sourceUrl: sourceUrl);
    return MediaRecord(id: id, sourceUrl: sourceUrl, mediaUrl: mediaUrl, thumbnailUrl: gif.previewUrl, title: gif.title, width: gif.width, height: gif.height, searchText: '${gif.title} ${gif.altText ?? ''} $sourceUrl $mediaUrl'.toLowerCase(), createdAt: gif.timestamp, updatedAt: DateTime.now(), lastViewedAt: gif.timestamp, lastSeenAt: gif.timestamp);
  }

  GifItem _toGifItem(MediaRecord media) => GifItem(id: media.id, url: media.sourceUrl, title: media.title ?? '', previewUrl: media.thumbnailUrl, timestamp: media.lastViewedAt ?? media.createdAt ?? media.updatedAt ?? DateTime.now(), isViewed: true, imageUrl: media.mediaUrl, width: media.width, height: media.height);
  void _replace(List<GifItem> items) { _viewedGifs..clear()..addAll(items.take(_maxViewedGifs)); notifyListeners(); }
}
import 'package:flutter/foundation.dart';

import '../local/local_media_repository.dart';
import '../local/models/collection.dart';
import '../local/models/collection_item.dart';
import '../local/models/media_record.dart';
import 'collection_share_service.dart';
import 'media_cache_manager.dart';

enum CollectionShareStatus {
  idle,
  preparing,
  ready,
  failed,
}

/// UI-facing state for reusable collections and multi-collection preparation.
///
/// This controller deliberately contains no widget code. Screens can bind to
/// its selection, readiness, progress, and error state while
/// CollectionShareService remains responsible for orchestration.
class CollectionShareController extends ChangeNotifier {
  CollectionShareController(
    this.repository, {
    CollectionShareService? shareService,
    MediaCacheManager? cacheManager,
  }) {
    this.cacheManager = cacheManager ?? MediaCacheManager(repository);
    this.shareService = shareService ??
        CollectionShareService(
          repository,
          cacheManager: this.cacheManager,
        );
  }

  final LocalMediaRepository repository;
  late final MediaCacheManager cacheManager;
  late final CollectionShareService shareService;

  List<GifCollection> _collections = const [];
  final Set<String> _selectedCollectionIds = <String>{};
  final Map<String, CollectionCacheReadiness> _readiness =
      <String, CollectionCacheReadiness>{};
  final Map<String, CollectionSharePreparation> _preparations =
      <String, CollectionSharePreparation>{};
  final Map<String, List<CollectionItem>> _itemsByCollection =
      <String, List<CollectionItem>>{};
  final Map<String, MediaRecord> _mediaById = <String, MediaRecord>{};

  CollectionShareStatus _status = CollectionShareStatus.idle;
  Object? _error;
  int _completedCollections = 0;

  List<GifCollection> get collections => List.unmodifiable(_collections);
  Set<String> get selectedCollectionIds =>
      Set.unmodifiable(_selectedCollectionIds);
  Map<String, CollectionCacheReadiness> get readiness =>
      Map.unmodifiable(_readiness);
  CollectionShareStatus get status => _status;
  Object? get error => _error;
  int get completedCollections => _completedCollections;
  int get selectedCount => _selectedCollectionIds.length;
  bool get hasSelection => _selectedCollectionIds.isNotEmpty;

  double get progress {
    if (_selectedCollectionIds.isEmpty) return 0;
    return _completedCollections / _selectedCollectionIds.length;
  }

  bool get isReadyToShare =>
      hasSelection &&
      _status == CollectionShareStatus.ready &&
      _preparations.length == _selectedCollectionIds.length &&
      _preparations.values.every((item) => item.isEmpty || item.isReadyToShare);

  Future<void> loadCollections() async {
    _collections = await repository.listCollections();
    _selectedCollectionIds.removeWhere(
      (id) => !_collections.any((collection) => collection.id == id),
    );
    notifyListeners();
  }

  void toggleCollection(String collectionId) {
    if (_selectedCollectionIds.contains(collectionId)) {
      _selectedCollectionIds.remove(collectionId);
    } else {
      _selectedCollectionIds.add(collectionId);
    }
    _status = CollectionShareStatus.idle;
    _error = null;
    notifyListeners();
  }

  void selectAll() {
    _selectedCollectionIds
      ..clear()
      ..addAll(_collections.map((collection) => collection.id));
    _status = CollectionShareStatus.idle;
    _error = null;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCollectionIds.clear();
    _preparations.clear();
    _itemsByCollection.clear();
    _mediaById.clear();
    _readiness.clear();
    _completedCollections = 0;
    _status = CollectionShareStatus.idle;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshReadiness() async {
    for (final id in _selectedCollectionIds) {
      _readiness[id] = await cacheManager.getCollectionReadiness(id);
      // Reload durable membership/share state after a share attempt so the
      // UI reflects the SQLite state instead of retaining stale in-memory rows.
      await loadCollectionItems(id);
    }
    notifyListeners();
  }

  Future<void> prepareSelected() async {
    if (!hasSelection) {
      _status = CollectionShareStatus.idle;
      _error = StateError('No collections selected');
      notifyListeners();
      return;
    }

    _status = CollectionShareStatus.preparing;
    _error = null;
    _completedCollections = 0;
    _preparations.clear();
    notifyListeners();

    try {
      for (final id in _selectedCollectionIds) {
        final preparation = await shareService.prepareCollection(id);
        _preparations[id] = preparation;
        _readiness[id] = preparation.readiness;
        await loadCollectionItems(id);
        _completedCollections++;
        notifyListeners();
      }

      _status = isReadyToShare
          ? CollectionShareStatus.ready
          : CollectionShareStatus.failed;
    } catch (error) {
      _error = error;
      _status = CollectionShareStatus.failed;
    }
    notifyListeners();
  }

  List<CollectionSharePreparation> get preparations =>
      List.unmodifiable(_preparations.values);

  List<CollectionItem> itemsForCollection(String collectionId) =>
      List.unmodifiable(_itemsByCollection[collectionId] ?? const []);

  MediaRecord? mediaForItem(String mediaId) => _mediaById[mediaId];

  Future<void> loadCollectionItems(String collectionId) async {
    final items = await repository.listCollectionItems(
      collectionId,
      pendingOnly: false,
      limit: 500,
    );
    _itemsByCollection[collectionId] = items;
    for (final item in items) {
      final media = await repository.getMedia(item.mediaId);
      if (media != null) _mediaById[item.mediaId] = media;
    }
    notifyListeners();
  }

  /// Makes all saved items in a reusable collection eligible for sharing
  /// again without deleting their records or cached media.
  Future<void> resetCollectionForSharing(String collectionId) async {
    await repository.resetCollectionItemsToPending(collectionId);
    _preparations.remove(collectionId);
    _readiness[collectionId] =
        await cacheManager.getCollectionReadiness(collectionId);
    await loadCollectionItems(collectionId);
    _status = CollectionShareStatus.idle;
    _error = null;
    notifyListeners();
  }

  Future<void> retryItem(String collectionId, String mediaId) async {
    final media = await repository.getMedia(mediaId);
    if (media == null) {
      _error = StateError('Media $mediaId no longer exists');
      _status = CollectionShareStatus.failed;
      notifyListeners();
      return;
    }

    _error = null;
    _status = CollectionShareStatus.preparing;
    notifyListeners();

    await cacheManager.prepareMedia(media, collectionId: collectionId);
    await _refreshCollectionAfterRecovery(collectionId);
  }

  Future<void> retryFailedOrExpired(String collectionId) async {
    final items = await repository.listCollectionItems(
      collectionId,
      pendingOnly: true,
      limit: 500,
    );

    _error = null;
    _status = CollectionShareStatus.preparing;
    notifyListeners();

    for (final item in items) {
      if (item.cacheState != CollectionCacheState.failed &&
          item.cacheState != CollectionCacheState.expired) {
        continue;
      }
      final media = await repository.getMedia(item.mediaId);
      if (media == null) continue;
      await cacheManager.prepareMedia(
        media,
        collectionId: collectionId,
      );
    }

    await _refreshCollectionAfterRecovery(collectionId);
  }

  Future<void> _refreshCollectionAfterRecovery(String collectionId) async {
    await loadCollectionItems(collectionId);
    _readiness[collectionId] =
        await cacheManager.getCollectionReadiness(collectionId);

    if (_selectedCollectionIds.contains(collectionId)) {
      final preparation = await shareService.prepareCollection(collectionId);
      _preparations[collectionId] = preparation;
      _readiness[collectionId] = preparation.readiness;

      _status = _preparations.length == _selectedCollectionIds.length &&
              _preparations.values.every((item) => item.isReadyToShare)
          ? CollectionShareStatus.ready
          : CollectionShareStatus.failed;
    } else {
      _status = CollectionShareStatus.idle;
    }

    notifyListeners();
  }

}

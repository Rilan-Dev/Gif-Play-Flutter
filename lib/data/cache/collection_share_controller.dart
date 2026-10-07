import 'package:flutter/foundation.dart';

import '../local/local_media_repository.dart';
import '../local/models/collection.dart';
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
      _preparations.values.every((item) => item.isReadyToShare);

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
    _readiness.clear();
    _completedCollections = 0;
    _status = CollectionShareStatus.idle;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshReadiness() async {
    for (final id in _selectedCollectionIds) {
      _readiness[id] = await cacheManager.getCollectionReadiness(id);
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
}

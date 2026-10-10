import 'package:flutter/foundation.dart';

import '../local/local_media_repository.dart';
import '../local/media_identity.dart';
import '../local/models/media_record.dart';
import '../local/models/detail_tab.dart';
import '../local/models/space.dart';

class SessionNavigationController extends ChangeNotifier {
  SessionNavigationController(this.repository);

  final LocalMediaRepository repository;

  List<BrowsingSpace> _spaces = const [];
  final Map<String, List<DetailTab>> _tabsBySpace =
      <String, List<DetailTab>>{};
  String? _activeSpaceId;
  String? _activeDetailTabId;
  bool _loaded = false;

  List<BrowsingSpace> get spaces => List.unmodifiable(_spaces);
  String? get activeSpaceId => _activeSpaceId;
  String? get activeDetailTabId => _activeDetailTabId;
  bool get isLoaded => _loaded;

  List<DetailTab> tabsForSpace(String spaceId) =>
      List.unmodifiable(_tabsBySpace[spaceId] ?? const []);

  BrowsingSpace? get activeSpace {
    for (final space in _spaces) {
      if (space.id == _activeSpaceId) return space;
    }
    return null;
  }

  DetailTab? get activeDetailTab {
    final activeSpace = _activeSpaceId;
    final activeTab = _activeDetailTabId;
    if (activeSpace == null || activeTab == null) return null;
    for (final tab in tabsForSpace(activeSpace)) {
      if (tab.id == activeTab && !tab.isClosed) return tab;
    }
    return null;
  }

  Future<void> load() async {
    _spaces = await repository.listSpaces();
    _tabsBySpace.clear();
    for (final space in _spaces) {
      _tabsBySpace[space.id] = await repository.listDetailTabs(space.id);
    }

    final snapshot = await repository.getSessionSnapshot();
    _activeSpaceId = _validSpaceId(snapshot?.activeSpaceId);
    _activeDetailTabId = _validTabId(
      snapshot?.activeDetailTabId,
      _activeSpaceId,
    );

    if (_spaces.isEmpty) {
      final home = await repository.createSpace(
        name: 'Home',
        feedType: 'home',
        sortOrder: 0,
      );
      _spaces = [home];
      _tabsBySpace[home.id] = const [];
    }

    if (_activeSpaceId == null) {
      _activeSpaceId = _spaces.first.id;
    }

    // A snapshot can outlive a tab (explicit close) or point at a tab owned
    // by a different Space. Repair it from durable Space/tab state instead
    // of restoring an invalid reference or leaving the snapshot stale.
    final activeSpace = _spaces.firstWhere(
      (space) => space.id == _activeSpaceId,
    );
    final tabs = _tabsBySpace[_activeSpaceId] ?? const <DetailTab>[];
    final snapshotMatchesActiveSpace =
        snapshot?.activeSpaceId == _activeSpaceId;
    if (snapshotMatchesActiveSpace && snapshot?.activeDetailTabId == null) {
      // A null tab in a matching session snapshot is an intentional Home-feed
      // selection, not a missing value to replace with the last child tab.
      _activeDetailTabId = null;
    } else {
      _activeDetailTabId =
          _validTabId(snapshot?.activeDetailTabId, _activeSpaceId) ??
          _validTabId(activeSpace.activeDetailTabId, _activeSpaceId) ??
          (tabs.isEmpty ? null : tabs.last.id);
    }

    if (snapshot?.activeSpaceId != _activeSpaceId ||
        snapshot?.activeDetailTabId != _activeDetailTabId ||
        activeSpace.activeDetailTabId != _activeDetailTabId) {
      await repository.updateSpace(
        id: _activeSpaceId!,
        activeDetailTabId: _activeDetailTabId,
        clearActiveDetailTabId: _activeDetailTabId == null,
      );
      await _persistSession();
    }

    _loaded = true;
    notifyListeners();
  }

  Future<BrowsingSpace> createSpace({
    String name = 'Space',
    String feedType = 'home',
  }) async {
    final space = await repository.createSpace(
      name: name,
      feedType: feedType,
      sortOrder: _spaces.length,
    );
    _spaces = [..._spaces, space];
    _tabsBySpace[space.id] = const [];
    await _activateSpace(space.id);
    notifyListeners();
    return space;
  }

  Future<void> activateSpace(String spaceId) async {
    if (_validSpaceId(spaceId) == null) return;
    await _activateSpace(spaceId);
    notifyListeners();
  }

  Future<DetailTab?> openDetailTab({
    required String spaceId,
    String? mediaId,
    String? canonicalUrl,
    String? title,
    String? thumbnailUrl,
    String? stateJson,
  }) async {
    if (_validSpaceId(spaceId) == null) return null;

    // Opening a GIF is an explicit navigation action: always create a new
    // child tab, even when the same GIF already has another open tab.
    //
    // detail_tabs.media_id is a foreign key into media_records. Legacy UI
    // callers used to pass the image URL itself as mediaId, which caused
    // SQLite to reject tab creation. Normalize and persist the media record
    // first, then store its canonical ID in the tab.
    var storedMediaId = mediaId;
    if (mediaId != null && await repository.getMedia(mediaId) == null) {
      final candidateUrl = _firstHttpUrl([
        thumbnailUrl,
        mediaId,
        canonicalUrl,
      ]);
      if (candidateUrl != null) {
        final sourceUrl = _firstHttpUrl([canonicalUrl, candidateUrl])!;
        final isUrlIdentity = mediaId.startsWith('http://') ||
            mediaId.startsWith('https://');
        final canonicalId = isUrlIdentity
            ? MediaIdentity.fromUrls(
                mediaUrl: candidateUrl,
                sourceUrl: sourceUrl,
              )
            : mediaId;
        await repository.upsertMedia(MediaRecord(
          id: canonicalId,
          sourceUrl: sourceUrl,
          mediaUrl: candidateUrl,
          thumbnailUrl: thumbnailUrl,
          title: title,
          searchText: '${title ?? ''} $sourceUrl $candidateUrl'.toLowerCase(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
        ));
        storedMediaId = canonicalId;
      } else {
        // A non-URL provider ID without a resolvable media URL cannot be
        // linked safely; preserve the tab metadata without a foreign key.
        storedMediaId = null;
      }
    }

    final tabs = tabsForSpace(spaceId);
    final tab = await repository.createDetailTab(
      spaceId: spaceId,
      mediaId: storedMediaId,
      canonicalUrl: canonicalUrl,
      title: title,
      thumbnailUrl: thumbnailUrl,
      stateJson: stateJson,
      sortOrder: tabs.fold<int>(-1, (latest, tab) =>
          tab.sortOrder > latest ? tab.sortOrder : latest) + 1,
    );

    _tabsBySpace[spaceId] = [...tabs, tab];
    _activeSpaceId = spaceId;
    _activeDetailTabId = tab.id;
    await _persistSession();
    await _reloadSpace(spaceId);
    notifyListeners();
    return tab;
  }

  /// Returns to the feed without closing any child tabs.
  Future<void> activateHomeFeed(String spaceId) async {
    if (_validSpaceId(spaceId) == null) return;
    _activeSpaceId = spaceId;
    _activeDetailTabId = null;
    await repository.updateSpace(
      id: spaceId,
      clearActiveDetailTabId: true,
    );
    _spaces = await repository.listSpaces();
    await _persistSession();
    notifyListeners();
  }

  Future<void> activateDetailTab(String tabId) async {
    final tab = await repository.getDetailTab(tabId);
    if (tab == null || tab.isClosed) return;
    _activeSpaceId = tab.spaceId;
    _activeDetailTabId = tab.id;
    await repository.updateSpace(
      id: tab.spaceId,
      activeDetailTabId: tab.id,
    );
    _spaces = await repository.listSpaces();
    await _persistSession();
    notifyListeners();
  }

  Future<void> updateActiveDetailTab({
    double? scrollOffset,
    String? stateJson,
  }) async {
    final tabId = _activeDetailTabId;
    if (tabId == null) return;
    await repository.updateDetailTab(
      id: tabId,
      scrollOffset: scrollOffset,
      stateJson: stateJson,
    );
    await _reloadSpace(_activeSpaceId);
    notifyListeners();
  }

  Future<void> closeDetailTab(String tabId) async {
    final tab = await repository.getDetailTab(tabId);
    if (tab == null) return;

    await repository.closeDetailTab(tabId);
    await _reloadSpace(tab.spaceId);

    if (_activeDetailTabId == tabId) {
      final remaining = tabsForSpace(tab.spaceId);
      _activeDetailTabId = remaining.isEmpty ? null : remaining.last.id;
      _activeSpaceId = tab.spaceId;
      await repository.updateSpace(
        id: tab.spaceId,
        activeDetailTabId: _activeDetailTabId,
        clearActiveDetailTabId: _activeDetailTabId == null,
      );
      await _persistSession();
    }
    notifyListeners();
  }

  Future<void> closeSpace(String spaceId) async {
    if (_validSpaceId(spaceId) == null) return;
    await repository.deleteSpace(spaceId);
    _tabsBySpace.remove(spaceId);
    _spaces = _spaces.where((space) => space.id != spaceId).toList();

    if (_activeSpaceId == spaceId) {
      _activeSpaceId = _spaces.isEmpty ? null : _spaces.first.id;
      _activeDetailTabId = _activeSpaceId == null
          ? null
          : tabsForSpace(_activeSpaceId!).isNotEmpty
              ? tabsForSpace(_activeSpaceId!).last.id
              : null;
      await _persistSession();
    }
    notifyListeners();
  }

  String? _firstHttpUrl(Iterable<String?> values) {
    for (final value in values) {
      final candidate = value?.trim() ?? '';
      final uri = Uri.tryParse(candidate);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  String? _validSpaceId(String? id) {
    if (id == null) return null;
    return _spaces.any((space) => space.id == id) ? id : null;
  }

  String? _validTabId(String? id, String? spaceId) {
    if (id == null || spaceId == null) return null;
    return tabsForSpace(spaceId).any((tab) => tab.id == id && !tab.isClosed)
        ? id
        : null;
  }

  Future<void> _activateSpace(String spaceId) async {
    _activeSpaceId = spaceId;
    final targetSpace = _spaces.firstWhere((space) => space.id == spaceId);
    // Each Space owns its own active child tab. Never carry the previous
    // Space's tab selection into the new Space.
    _activeDetailTabId = _validTabId(
      targetSpace.activeDetailTabId,
      spaceId,
    );
    // A null persisted pointer means this Space was left on its Home feed.
    // Only repair a non-null but stale pointer by selecting the last live tab.
    if (targetSpace.activeDetailTabId != null && _activeDetailTabId == null) {
      final tabs = tabsForSpace(spaceId);
      _activeDetailTabId = tabs.isEmpty ? null : tabs.last.id;
    }
    await repository.updateSpace(
      id: spaceId,
      activeDetailTabId: _activeDetailTabId,
      clearActiveDetailTabId: _activeDetailTabId == null,
    );
    _spaces = await repository.listSpaces();
    await _persistSession();
  }

  Future<void> _reloadSpace(String? spaceId) async {
    if (spaceId == null) return;
    _tabsBySpace[spaceId] = await repository.listDetailTabs(spaceId);
    _spaces = await repository.listSpaces();
  }

  Future<void> _persistSession() {
    return repository.saveSessionSnapshot(
      activeSpaceId: _activeSpaceId,
      activeDetailTabId: _activeDetailTabId,
    );
  }
}

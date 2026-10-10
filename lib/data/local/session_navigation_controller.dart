import 'package:flutter/foundation.dart';

import '../local/local_media_repository.dart';
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
    _activeDetailTabId =
        _validTabId(snapshot?.activeDetailTabId, _activeSpaceId) ??
        _validTabId(activeSpace.activeDetailTabId, _activeSpaceId) ??
        (tabs.isEmpty ? null : tabs.last.id);

    if (snapshot?.activeSpaceId != _activeSpaceId ||
        snapshot?.activeDetailTabId != _activeDetailTabId) {
      await repository.updateSpace(
        id: _activeSpaceId!,
        activeDetailTabId: _activeDetailTabId,
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

    final existing = (await repository.listDetailTabs(spaceId)).where(
      (tab) =>
          mediaId != null && tab.mediaId == mediaId && !tab.isClosed,
    );
    if (existing.isNotEmpty) {
      await activateDetailTab(existing.first.id);
      return existing.first;
    }

    final tabs = tabsForSpace(spaceId);
    final tab = await repository.createDetailTab(
      spaceId: spaceId,
      mediaId: mediaId,
      canonicalUrl: canonicalUrl,
      title: title,
      thumbnailUrl: thumbnailUrl,
      stateJson: stateJson,
      sortOrder: tabs.length,
    );

    _tabsBySpace[spaceId] = [...tabs, tab];
    _activeSpaceId = spaceId;
    _activeDetailTabId = tab.id;
    await _persistSession();
    await _reloadSpace(spaceId);
    notifyListeners();
    return tab;
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
    _activeDetailTabId = _validTabId(
      _activeDetailTabId,
      spaceId,
    );
    if (_activeDetailTabId == null) {
      final tabs = tabsForSpace(spaceId);
      _activeDetailTabId = tabs.isEmpty ? null : tabs.last.id;
    }
    await repository.updateSpace(
      id: spaceId,
      activeDetailTabId: _activeDetailTabId,
    );
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

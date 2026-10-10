import 'package:drift/drift.dart';

import 'local_database.dart';
import 'media_identity.dart';
import 'models/collection.dart';
import 'models/collection_item.dart';
import 'models/media_cache_entry.dart';
import 'models/media_record.dart';
import 'models/space.dart';
import 'models/detail_tab.dart';
import 'models/session_snapshot.dart';

class LocalMediaRepository {
  LocalMediaRepository(this.database);

  final LocalDatabase database;

  Future<void> upsertMedia(MediaRecord media) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.customInsert(
      '''
      INSERT INTO media_records (
        id, source_url, media_url, thumbnail_url, title, source_name,
        width, height, mime_type, tags_text, search_text,
        created_at, updated_at, last_viewed_at, last_seen_at, schema_version
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        source_url = excluded.source_url,
        media_url = excluded.media_url,
        thumbnail_url = COALESCE(excluded.thumbnail_url, media_records.thumbnail_url),
        title = COALESCE(excluded.title, media_records.title),
        source_name = COALESCE(excluded.source_name, media_records.source_name),
        width = COALESCE(excluded.width, media_records.width),
        height = COALESCE(excluded.height, media_records.height),
        mime_type = COALESCE(excluded.mime_type, media_records.mime_type),
        tags_text = COALESCE(excluded.tags_text, media_records.tags_text),
        search_text = excluded.search_text,
        updated_at = excluded.updated_at,
        last_viewed_at = COALESCE(excluded.last_viewed_at, media_records.last_viewed_at),
        last_seen_at = COALESCE(excluded.last_seen_at, media_records.last_seen_at)
      ''',
      variables: [
        Variable.withString(media.id),
        Variable.withString(media.sourceUrl),
        Variable.withString(media.mediaUrl),
        Variable<String>(media.thumbnailUrl),
        Variable<String>(media.title),
        Variable<String>(media.sourceName),
        Variable<int>(media.width),
        Variable<int>(media.height),
        Variable<String>(media.mimeType),
        Variable<String>(media.tagsText),
        Variable.withString(media.searchText),
        Variable.withInt(media.createdAt?.millisecondsSinceEpoch ?? now),
        Variable.withInt(media.updatedAt?.millisecondsSinceEpoch ?? now),
        Variable<int>(media.lastViewedAt?.millisecondsSinceEpoch),
        Variable<int>(media.lastSeenAt?.millisecondsSinceEpoch),
        Variable.withInt(media.schemaVersion),
      ],
    );
  }

  Future<MediaRecord?> getMedia(String mediaId) async {
    final rows = await database.customSelect(
      'SELECT * FROM media_records WHERE id = ? LIMIT 1',
      variables: [Variable.withString(mediaId)],
    ).get();
    return rows.isEmpty ? null : _mediaFromRow(rows.single);
  }

  Future<List<MediaRecord>> searchMedia(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    final normalized = query.trim().toLowerCase();
    final rows = normalized.isEmpty
        ? await database.customSelect(
            '''
            SELECT * FROM media_records
            ORDER BY COALESCE(last_viewed_at, updated_at) DESC
            LIMIT ? OFFSET ?
            ''',
            variables: [Variable.withInt(limit), Variable.withInt(offset)],
          ).get()
        : await database.customSelect(
            '''
            SELECT * FROM media_records
            WHERE search_text LIKE ?
               OR source_url LIKE ?
               OR media_url LIKE ?
            ORDER BY COALESCE(last_viewed_at, updated_at) DESC
            LIMIT ? OFFSET ?
            ''',
            variables: [
              Variable.withString('%$normalized%'),
              Variable.withString('%$normalized%'),
              Variable.withString('%$normalized%'),
              Variable.withInt(limit),
              Variable.withInt(offset),
            ],
          ).get();
    return rows.map(_mediaFromRow).toList(growable: false);
  }

  Future<int> countMedia() async {
    final row = await database
        .customSelect('SELECT COUNT(*) AS count FROM media_records')
        .getSingle();
    return row.read<int>('count');
  }

  Future<GifCollection> createCollection(
    String name, {
    String? id,
    int? sortOrder,
  }) async {
    final collectionId = id ?? _newId();
    final now = DateTime.now();
    await database.customInsert(
      '''
      INSERT INTO collections
        (id, name, created_at, updated_at, sort_order, is_archived)
      VALUES (?, ?, ?, ?, ?, 0)
      ''',
      variables: [
        Variable.withString(collectionId),
        Variable.withString(name.trim()),
        Variable.withInt(now.millisecondsSinceEpoch),
        Variable.withInt(now.millisecondsSinceEpoch),
        Variable.withInt(sortOrder ?? 0),
      ],
    );
    return (await getCollection(collectionId))!;
  }

  Future<GifCollection?> getCollection(String collectionId) async {
    final rows = await database.customSelect(
      'SELECT * FROM collections WHERE id = ? LIMIT 1',
      variables: [Variable.withString(collectionId)],
    ).get();
    return rows.isEmpty ? null : _collectionFromRow(rows.single);
  }

  Future<List<GifCollection>> listCollections({
    bool includeArchived = false,
  }) async {
    final rows = await database.customSelect(
      '''
      SELECT * FROM collections
      WHERE is_archived = 0 OR ? = 1
      ORDER BY sort_order ASC, updated_at DESC
      ''',
      variables: [Variable.withInt(includeArchived ? 1 : 0)],
    ).get();
    return rows.map(_collectionFromRow).toList(growable: false);
  }

  Future<void> renameCollection(String id, String name) async {
    await database.customUpdate(
      'UPDATE collections SET name = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withString(name.trim()),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(id),
      ],
      updateKind: UpdateKind.update,
    );
  }

  Future<void> addToCollection({
    required String collectionId,
    required MediaRecord media,
    int? position,
  }) async {
    await database.transaction(() async {
      await upsertMedia(media);
      final nextPosition =
          position ?? await _nextCollectionPosition(collectionId);
      await database.customInsert(
        '''
        INSERT INTO collection_items
          (collection_id, media_id, position, added_at, share_state, cache_state)
        VALUES (?, ?, ?, ?, 'pending', 'notCached')
        ON CONFLICT(collection_id, media_id) DO UPDATE SET
          position = excluded.position,
          share_state = 'pending',
          last_error = NULL
        ''',
        variables: [
          Variable.withString(collectionId),
          Variable.withString(media.id),
          Variable.withInt(nextPosition),
          Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        ],
      );
      await database.customUpdate(
        'UPDATE collections SET updated_at = ?, last_used_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(DateTime.now().millisecondsSinceEpoch),
          Variable.withInt(DateTime.now().millisecondsSinceEpoch),
          Variable.withString(collectionId),
        ],
        updateKind: UpdateKind.update,
      );
    });
  }

  Future<List<MediaRecord>> listCollectionMedia(
    String collectionId, {
    bool pendingOnly = false,
    int limit = 500,
    int offset = 0,
  }) async {
    final rows = await database.customSelect(
      '''
      SELECT m.*
      FROM media_records m
      INNER JOIN collection_items ci ON ci.media_id = m.id
      WHERE ci.collection_id = ?
        AND (? = 0 OR ci.share_state = 'pending')
      ORDER BY ci.position ASC, ci.added_at ASC
      LIMIT ? OFFSET ?
      ''',
      variables: [
        Variable.withString(collectionId),
        Variable.withInt(pendingOnly ? 1 : 0),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
    ).get();
    return rows.map(_mediaFromRow).toList(growable: false);
  }

  Future<void> clearCollectionItems(String collectionId) async {
    await database.customUpdate(
      'DELETE FROM collection_items WHERE collection_id = ?',
      variables: [Variable.withString(collectionId)],
      updateKind: UpdateKind.delete,
    );
    await database.customUpdate(
      'UPDATE collections SET updated_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(collectionId),
      ],
      updateKind: UpdateKind.update,
    );
  }

  Future<void> updateCollectionItemCacheState({
    required String collectionId,
    required String mediaId,
    required CollectionCacheState cacheState,
    String? error,
  }) async {
    await database.customUpdate(
      '''
      UPDATE collection_items
      SET cache_state = ?, last_error = ?
      WHERE collection_id = ? AND media_id = ?
      ''',
      variables: [
        Variable.withString(cacheState.name),
        Variable<String>(error),
        Variable.withString(collectionId),
        Variable.withString(mediaId),
      ],
      updateKind: UpdateKind.update,
    );
  }

  Future<List<CollectionItem>> listReadyCollectionItems(
    String collectionId, {
    int limit = 500,
    int offset = 0,
  }) async {
    final rows = await database.customSelect(
      '''
      SELECT * FROM collection_items
      WHERE collection_id = ? AND cache_state = 'ready'
      ORDER BY position ASC, added_at ASC
      LIMIT ? OFFSET ?
      ''',
      variables: [
        Variable.withString(collectionId),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
    ).get();
    return rows.map(_collectionItemFromRow).toList(growable: false);
  }
  Future<List<CollectionItem>> listCollectionItems(
    String collectionId, {
    bool pendingOnly = false,
    int limit = 500,
    int offset = 0,
  }) async {
    final rows = await database.customSelect(
      '''
      SELECT * FROM collection_items
      WHERE collection_id = ?
        AND (? = 0 OR share_state = 'pending')
      ORDER BY position ASC, added_at ASC
      LIMIT ? OFFSET ?
      ''',
      variables: [
        Variable.withString(collectionId),
        Variable.withInt(pendingOnly ? 1 : 0),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
    ).get();
    return rows.map(_collectionItemFromRow).toList(growable: false);
  }

  Future<int> countCollectionItems(
    String collectionId, {
    bool pendingOnly = false,
  }) async {
    final row = await database.customSelect(
      '''
      SELECT COUNT(*) AS count FROM collection_items
      WHERE collection_id = ?
        AND (? = 0 OR share_state = 'pending')
      ''',
      variables: [
        Variable.withString(collectionId),
        Variable.withInt(pendingOnly ? 1 : 0),
      ],
    ).getSingle();
    return row.read<int>('count');
  }

  Future<void> markCollectionItemsShared(
    String collectionId,
    Iterable<String> mediaIds,
  ) async {
    final ids = mediaIds.toList(growable: false);
    if (ids.isEmpty) return;

    await database.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final mediaId in ids) {
        await database.customUpdate(
          '''
          UPDATE collection_items
          SET share_state = 'shared', shared_at = ?, last_error = NULL
          WHERE collection_id = ? AND media_id = ?
          ''',
          variables: [
            Variable.withInt(now),
            Variable.withString(collectionId),
            Variable.withString(mediaId),
          ],
          updateKind: UpdateKind.update,
        );
      }
      await database.customUpdate(
        'UPDATE collections SET updated_at = ?, last_used_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(now),
          Variable.withInt(now),
          Variable.withString(collectionId),
        ],
        updateKind: UpdateKind.update,
      );
    });
  }

  Future<void> resetCollectionItemsToPending(String collectionId) async {
    await database.customUpdate(
      '''
      UPDATE collection_items
      SET share_state = 'pending', shared_at = NULL, last_error = NULL
      WHERE collection_id = ?
      ''',
      variables: [Variable.withString(collectionId)],
      updateKind: UpdateKind.update,
    );
  }

  Future<void> removeFromCollection({
    required String collectionId,
    required String mediaId,
  }) async {
    await database.customUpdate(
      'DELETE FROM collection_items WHERE collection_id = ? AND media_id = ?',
      variables: [
        Variable.withString(collectionId),
        Variable.withString(mediaId),
      ],
      updateKind: UpdateKind.delete,
    );
  }

  Future<void> upsertCacheEntry(MediaCacheEntry entry) async {
    await database.customInsert(
      '''
      INSERT INTO media_cache_entries
        (media_id, local_path, byte_size, downloaded_at, last_accessed_at,
         expires_at, checksum, status, failure_count, last_error)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(media_id) DO UPDATE SET
        local_path = excluded.local_path,
        byte_size = excluded.byte_size,
        downloaded_at = excluded.downloaded_at,
        last_accessed_at = excluded.last_accessed_at,
        expires_at = excluded.expires_at,
        checksum = excluded.checksum,
        status = excluded.status,
        failure_count = excluded.failure_count,
        last_error = excluded.last_error
      ''',
      variables: [
        Variable.withString(entry.mediaId),
        Variable.withString(entry.localPath),
        Variable.withInt(entry.byteSize),
        Variable.withInt(entry.downloadedAt.millisecondsSinceEpoch),
        Variable.withInt(entry.lastAccessedAt.millisecondsSinceEpoch),
        Variable<int>(entry.expiresAt?.millisecondsSinceEpoch),
        Variable<String>(entry.checksum),
        Variable.withString(entry.status.name),
        Variable.withInt(entry.failureCount),
        Variable<String>(entry.lastError),
      ],
    );
  }

  Future<List<MediaCacheEntry>> listCacheEntries() async {
    final rows = await database.customSelect(
      'SELECT * FROM media_cache_entries ORDER BY last_accessed_at ASC',
    ).get();
    return rows.map(_cacheFromRow).toList(growable: false);
  }

  Future<int> countCacheBytes() async {
    final row = await database.customSelect(
      'SELECT COALESCE(SUM(byte_size), 0) AS bytes FROM media_cache_entries WHERE status = \'ready\'',
    ).getSingle();
    return row.read<int>('bytes');
  }

  Future<void> touchCacheEntry(String mediaId, {DateTime? accessedAt}) async {
    await database.customUpdate(
      'UPDATE media_cache_entries SET last_accessed_at = ? WHERE media_id = ?',
      variables: [
        Variable.withInt((accessedAt ?? DateTime.now()).millisecondsSinceEpoch),
        Variable.withString(mediaId),
      ],
      updateKind: UpdateKind.update,
    );
  }

  Future<void> deleteCacheEntry(String mediaId) async {
    await database.customUpdate(
      'DELETE FROM media_cache_entries WHERE media_id = ?',
      variables: [Variable.withString(mediaId)],
      updateKind: UpdateKind.delete,
    );
  }

  Future<MediaCacheEntry?> getCacheEntry(String mediaId) async {
    final rows = await database.customSelect(
      'SELECT * FROM media_cache_entries WHERE media_id = ? LIMIT 1',
      variables: [Variable.withString(mediaId)],
    ).get();
    return rows.isEmpty ? null : _cacheFromRow(rows.single);
  }

  Future<BrowsingSpace> createSpace({
    String? id,
    String name = 'Space',
    String feedType = 'home',
    int? sortOrder,
  }) async {
    final spaceId = id ?? _newNavigationId('space');
    final now = DateTime.now();
    await database.customInsert(
      '''
      INSERT INTO spaces
        (id, name, created_at, updated_at, feed_type, sort_order)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(spaceId),
        Variable.withString(name.trim()),
        Variable.withInt(now.millisecondsSinceEpoch),
        Variable.withInt(now.millisecondsSinceEpoch),
        Variable.withString(feedType),
        Variable.withInt(sortOrder ?? 0),
      ],
    );
    return (await getSpace(spaceId))!;
  }

  Future<BrowsingSpace?> getSpace(String spaceId) async {
    final rows = await database.customSelect(
      'SELECT * FROM spaces WHERE id = ? LIMIT 1',
      variables: [Variable.withString(spaceId)],
    ).get();
    return rows.isEmpty ? null : _spaceFromRow(rows.single);
  }

  Future<List<BrowsingSpace>> listSpaces() async {
    final rows = await database.customSelect(
      'SELECT * FROM spaces ORDER BY sort_order ASC, updated_at DESC',
    ).get();
    return rows.map(_spaceFromRow).toList(growable: false);
  }

  Future<void> updateSpace({
    required String id,
    String? name,
    String? feedType,
    int? feedPage,
    String? feedStateJson,
    String? searchQuery,
    String? filterStateJson,
    double? scrollOffset,
    String? activeDetailTabId,
    bool clearActiveDetailTabId = false,
    int? sortOrder,
  }) async {
    final current = await getSpace(id);
    if (current == null) throw StateError('Space $id does not exist');
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.customUpdate(
      '''
      UPDATE spaces SET
        name = ?, updated_at = ?, feed_type = ?, feed_page = ?,
        feed_state_json = ?, search_query = ?, filter_state_json = ?,
        scroll_offset = ?, active_detail_tab_id = ?, sort_order = ?
      WHERE id = ?
      ''',
      variables: [
        Variable.withString(name ?? current.name),
        Variable.withInt(now),
        Variable.withString(feedType ?? current.feedType),
        Variable<int>(feedPage ?? current.feedPage),
        Variable<String>(feedStateJson ?? current.feedStateJson),
        Variable<String>(searchQuery ?? current.searchQuery),
        Variable<String>(filterStateJson ?? current.filterStateJson),
        Variable<double>(scrollOffset ?? current.scrollOffset),
        Variable<String>(
          clearActiveDetailTabId
              ? null
              : activeDetailTabId ?? current.activeDetailTabId,
        ),
        Variable.withInt(sortOrder ?? current.sortOrder),
        Variable.withString(id),
      ],
      updateKind: UpdateKind.update,
    );
  }

  Future<void> deleteSpace(String spaceId) async {
    await database.customUpdate(
      'DELETE FROM spaces WHERE id = ?',
      variables: [Variable.withString(spaceId)],
      updateKind: UpdateKind.delete,
    );
  }

  Future<DetailTab> createDetailTab({
    required String spaceId,
    String? id,
    String? mediaId,
    String? canonicalUrl,
    String? title,
    String? thumbnailUrl,
    String? stateJson,
    int? sortOrder,
  }) async {
    final space = await getSpace(spaceId);
    if (space == null) throw StateError('Space $spaceId does not exist');
    final tabId = id ?? _newNavigationId('tab');
    final now = DateTime.now();
    await database.transaction(() async {
      await database.customInsert(
        '''
        INSERT INTO detail_tabs
          (id, space_id, media_id, canonical_url, title, thumbnail_url,
           opened_at, updated_at, last_accessed_at, state_json, sort_order, is_closed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        ''',
        variables: [
          Variable.withString(tabId),
          Variable.withString(spaceId),
          Variable<String>(mediaId),
          Variable<String>(canonicalUrl),
          Variable<String>(title),
          Variable<String>(thumbnailUrl),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable<String>(stateJson),
          Variable.withInt(sortOrder ?? 0),
        ],
      );
      await database.customUpdate(
        'UPDATE spaces SET active_detail_tab_id = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withString(tabId),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(spaceId),
        ],
        updateKind: UpdateKind.update,
      );
    });
    return (await getDetailTab(tabId))!;
  }

  Future<DetailTab?> getDetailTab(String tabId) async {
    final rows = await database.customSelect(
      'SELECT * FROM detail_tabs WHERE id = ? LIMIT 1',
      variables: [Variable.withString(tabId)],
    ).get();
    return rows.isEmpty ? null : _detailTabFromRow(rows.single);
  }

  Future<List<DetailTab>> listDetailTabs(
    String spaceId, {
    bool includeClosed = false,
  }) async {
    final rows = await database.customSelect(
      '''
      SELECT * FROM detail_tabs
      WHERE space_id = ? AND (? = 1 OR is_closed = 0)
      ORDER BY sort_order ASC, updated_at DESC
      ''',
      variables: [
        Variable.withString(spaceId),
        Variable.withInt(includeClosed ? 1 : 0),
      ],
    ).get();
    return rows.map(_detailTabFromRow).toList(growable: false);
  }

  Future<void> updateDetailTab({
    required String id,
    String? mediaId,
    String? canonicalUrl,
    String? title,
    String? thumbnailUrl,
    double? scrollOffset,
    String? stateJson,
    int? sortOrder,
    bool? isClosed,
    bool touchAccess = true,
  }) async {
    final current = await getDetailTab(id);
    if (current == null) throw StateError('Detail tab $id does not exist');
    final now = DateTime.now();
    await database.customUpdate(
      '''
      UPDATE detail_tabs SET
        media_id = ?, canonical_url = ?, title = ?, thumbnail_url = ?,
        updated_at = ?, last_accessed_at = ?, scroll_offset = ?,
        state_json = ?, sort_order = ?, is_closed = ?
      WHERE id = ?
      ''',
      variables: [
        Variable<String>(mediaId ?? current.mediaId),
        Variable<String>(canonicalUrl ?? current.canonicalUrl),
        Variable<String>(title ?? current.title),
        Variable<String>(thumbnailUrl ?? current.thumbnailUrl),
        Variable.withInt(now.millisecondsSinceEpoch),
        Variable.withInt(
          (touchAccess ? now : current.lastAccessedAt).millisecondsSinceEpoch,
        ),
        Variable<double>(scrollOffset ?? current.scrollOffset),
        Variable<String>(stateJson ?? current.stateJson),
        Variable.withInt(sortOrder ?? current.sortOrder),
        Variable.withInt((isClosed ?? current.isClosed) ? 1 : 0),
        Variable.withString(id),
      ],
      updateKind: UpdateKind.update,
    );
  }

  Future<void> closeDetailTab(String tabId) async {
    final tab = await getDetailTab(tabId);
    if (tab == null) return;
    await database.transaction(() async {
      await updateDetailTab(id: tabId, isClosed: true);
      final space = await getSpace(tab.spaceId);
      if (space?.activeDetailTabId == tabId) {
        final remaining = await listDetailTabs(tab.spaceId);
        await updateSpace(
          id: tab.spaceId,
          activeDetailTabId: remaining.isEmpty ? null : remaining.last.id,
          clearActiveDetailTabId: remaining.isEmpty,
        );
      }
    });
  }

  Future<SessionSnapshot?> getSessionSnapshot() async {
    final rows = await database.customSelect(
      'SELECT * FROM session_snapshot WHERE id = 1 LIMIT 1',
    ).get();
    return rows.isEmpty ? null : _sessionSnapshotFromRow(rows.single);
  }

  Future<void> saveSessionSnapshot({
    required String? activeSpaceId,
    required String? activeDetailTabId,
  }) async {
    final now = DateTime.now();
    await database.customInsert(
      '''
      INSERT INTO session_snapshot
        (id, active_space_id, active_detail_tab_id, updated_at, schema_version)
      VALUES (1, ?, ?, ?, 1)
      ON CONFLICT(id) DO UPDATE SET
        active_space_id = excluded.active_space_id,
        active_detail_tab_id = excluded.active_detail_tab_id,
        updated_at = excluded.updated_at,
        schema_version = excluded.schema_version
      ''',
      variables: [
        Variable<String>(activeSpaceId),
        Variable<String>(activeDetailTabId),
        Variable.withInt(now.millisecondsSinceEpoch),
      ],
    );
  }

  Future<int> _nextCollectionPosition(String collectionId) async {
    final row = await database.customSelect(
      '''
      SELECT COALESCE(MAX(position), -1) + 1 AS next_position
      FROM collection_items WHERE collection_id = ?
      ''',
      variables: [Variable.withString(collectionId)],
    ).getSingle();
    return row.read<int>('next_position');
  }

  BrowsingSpace _spaceFromRow(QueryRow row) {
    DateTime date(int value) => DateTime.fromMillisecondsSinceEpoch(value);
    return BrowsingSpace(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      createdAt: date(row.read<int>('created_at')),
      updatedAt: date(row.read<int>('updated_at')),
      feedType: row.read<String>('feed_type'),
      feedPage: row.read<int?>('feed_page'),
      feedStateJson: row.read<String?>('feed_state_json'),
      searchQuery: row.read<String?>('search_query'),
      filterStateJson: row.read<String?>('filter_state_json'),
      scrollOffset: row.read<double?>('scroll_offset'),
      activeDetailTabId: row.read<String?>('active_detail_tab_id'),
      sortOrder: row.read<int>('sort_order'),
    );
  }

  DetailTab _detailTabFromRow(QueryRow row) {
    DateTime date(int value) => DateTime.fromMillisecondsSinceEpoch(value);
    return DetailTab(
      id: row.read<String>('id'),
      spaceId: row.read<String>('space_id'),
      mediaId: row.read<String?>('media_id'),
      canonicalUrl: row.read<String?>('canonical_url'),
      title: row.read<String?>('title'),
      thumbnailUrl: row.read<String?>('thumbnail_url'),
      openedAt: date(row.read<int>('opened_at')),
      updatedAt: date(row.read<int>('updated_at')),
      lastAccessedAt: date(row.read<int>('last_accessed_at')),
      scrollOffset: row.read<double?>('scroll_offset'),
      stateJson: row.read<String?>('state_json'),
      sortOrder: row.read<int>('sort_order'),
      isClosed: row.read<int>('is_closed') == 1,
    );
  }

  SessionSnapshot _sessionSnapshotFromRow(QueryRow row) {
    return SessionSnapshot(
      activeSpaceId: row.read<String?>('active_space_id'),
      activeDetailTabId: row.read<String?>('active_detail_tab_id'),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
      schemaVersion: row.read<int>('schema_version'),
    );
  }

  MediaRecord _mediaFromRow(QueryRow row) {
    DateTime? date(int? value) =>
        value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
    return MediaRecord(
      id: row.read<String>('id'),
      sourceUrl: row.read<String>('source_url'),
      mediaUrl: row.read<String>('media_url'),
      thumbnailUrl: row.read<String?>('thumbnail_url'),
      title: row.read<String?>('title'),
      sourceName: row.read<String?>('source_name'),
      width: row.read<int?>('width'),
      height: row.read<int?>('height'),
      mimeType: row.read<String?>('mime_type'),
      tagsText: row.read<String?>('tags_text'),
      searchText: row.read<String>('search_text'),
      createdAt: date(row.read<int>('created_at')),
      updatedAt: date(row.read<int>('updated_at')),
      lastViewedAt: date(row.read<int?>('last_viewed_at')),
      lastSeenAt: date(row.read<int?>('last_seen_at')),
      schemaVersion: row.read<int>('schema_version'),
    );
  }

  GifCollection _collectionFromRow(QueryRow row) {
    DateTime date(int value) => DateTime.fromMillisecondsSinceEpoch(value);
    return GifCollection(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      createdAt: date(row.read<int>('created_at')),
      updatedAt: date(row.read<int>('updated_at')),
      lastUsedAt: row.read<int?>('last_used_at') == null
          ? null
          : date(row.read<int>('last_used_at')!),
      sortOrder: row.read<int>('sort_order'),
      isArchived: row.read<int>('is_archived') == 1,
    );
  }

  CollectionItem _collectionItemFromRow(QueryRow row) {
    DateTime date(int value) => DateTime.fromMillisecondsSinceEpoch(value);
    return CollectionItem(
      collectionId: row.read<String>('collection_id'),
      mediaId: row.read<String>('media_id'),
      position: row.read<int>('position'),
      addedAt: date(row.read<int>('added_at')),
      shareState:
          CollectionShareState.values.byName(row.read<String>('share_state')),
      cacheState:
          CollectionCacheState.values.byName(row.read<String>('cache_state')),
      sharedAt: row.read<int?>('shared_at') == null
          ? null
          : date(row.read<int>('shared_at')!),
      lastError: row.read<String?>('last_error'),
    );
  }

  MediaCacheEntry _cacheFromRow(QueryRow row) {
    DateTime date(int value) => DateTime.fromMillisecondsSinceEpoch(value);
    return MediaCacheEntry(
      mediaId: row.read<String>('media_id'),
      localPath: row.read<String>('local_path'),
      byteSize: row.read<int>('byte_size'),
      downloadedAt: date(row.read<int>('downloaded_at')),
      lastAccessedAt: date(row.read<int>('last_accessed_at')),
      expiresAt: row.read<int?>('expires_at') == null
          ? null
          : date(row.read<int>('expires_at')!),
      checksum: row.read<String?>('checksum'),
      status: MediaCacheStatus.values.byName(row.read<String>('status')),
      failureCount: row.read<int>('failure_count'),
      lastError: row.read<String?>('last_error'),
    );
  }

  String _newNavigationId(String prefix) => MediaIdentity.fromUrls(
        mediaUrl: '$prefix|${DateTime.now().microsecondsSinceEpoch}',
      );

  String _newId() => MediaIdentity.fromUrls(
        mediaUrl: DateTime.now().microsecondsSinceEpoch.toString() + '|collection',
      );
}

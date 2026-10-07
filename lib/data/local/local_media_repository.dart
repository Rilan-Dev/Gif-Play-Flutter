import 'package:drift/drift.dart';

import 'local_database.dart';
import 'media_identity.dart';
import 'models/collection.dart';
import 'models/collection_item.dart';
import 'models/media_cache_entry.dart';
import 'models/media_record.dart';

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

  String _newId() => MediaIdentity.fromUrls(
        mediaUrl: DateTime.now().microsecondsSinceEpoch.toString() + '|collection',
      );
}

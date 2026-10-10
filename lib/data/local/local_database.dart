import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Drift-backed SQLite connection used by the local media repositories.
///
/// This first Phase 1 slice uses Drift's prepared custom SQL API rather than
/// generated tables so the repository can be introduced without requiring a
/// generator artifact to be committed. The schema remains explicit SQL and is
/// versioned through SQLite's user_version pragma.
class LocalDatabase extends GeneratedDatabase {
  LocalDatabase._(QueryExecutor executor) : super(executor);

  LocalDatabase.forTesting(QueryExecutor executor) : super(executor);

  factory LocalDatabase.open() {
    return LocalDatabase._(
      driftDatabase(name: 'gif_play_library'),
    );
  }

  static const int currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async {
          await _createSchema();
        },
        onUpgrade: (_, from, to) async {
          await _migrate(from, to);
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> initialize() async {
    await customStatement('PRAGMA foreign_keys = ON');

    final versionRow = await customSelect('PRAGMA user_version').getSingle();
    final version = versionRow.read<int>('user_version');

    if (version == 0) {
      await transaction(() async {
        await _createSchema();
        await customStatement('PRAGMA user_version = $currentSchemaVersion');
      });
      return;
    }

    if (version < currentSchemaVersion) {
      await _migrate(version, currentSchemaVersion);
    }

    if (version > currentSchemaVersion) {
      throw StateError(
        'GIF Play database version $version is newer than the supported '
        'version $currentSchemaVersion.',
      );
    }
  }

  Future<void> _createSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS media_records (
        id TEXT PRIMARY KEY,
        source_url TEXT NOT NULL,
        media_url TEXT NOT NULL,
        thumbnail_url TEXT,
        title TEXT,
        source_name TEXT,
        width INTEGER,
        height INTEGER,
        mime_type TEXT,
        tags_text TEXT,
        search_text TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_viewed_at INTEGER,
        last_seen_at INTEGER,
        schema_version INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_media_records_updated
      ON media_records(updated_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_media_records_last_viewed
      ON media_records(last_viewed_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_media_records_source_url
      ON media_records(source_url)
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS collections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_used_at INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_collections_order
      ON collections(sort_order, updated_at DESC)
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS collection_items (
        collection_id TEXT NOT NULL,
        media_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        share_state TEXT NOT NULL DEFAULT 'pending',
        cache_state TEXT NOT NULL DEFAULT 'notCached',
        shared_at INTEGER,
        last_error TEXT,
        PRIMARY KEY (collection_id, media_id),
        FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_records(id) ON DELETE RESTRICT
      )
    ''');

    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_collection_items_pending
      ON collection_items(collection_id, share_state, position)
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS media_cache_entries (
        media_id TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        byte_size INTEGER NOT NULL DEFAULT 0,
        downloaded_at INTEGER NOT NULL,
        last_accessed_at INTEGER NOT NULL,
        expires_at INTEGER,
        checksum TEXT,
        status TEXT NOT NULL,
        failure_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        FOREIGN KEY (media_id) REFERENCES media_records(id) ON DELETE CASCADE
      )
    ''');

    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_media_cache_lru
      ON media_cache_entries(status, last_accessed_at)
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS spaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        feed_type TEXT NOT NULL DEFAULT 'home',
        feed_page INTEGER,
        feed_state_json TEXT,
        search_query TEXT,
        filter_state_json TEXT,
        scroll_offset REAL,
        active_detail_tab_id TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_spaces_order
      ON spaces(sort_order, updated_at DESC)
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS detail_tabs (
        id TEXT PRIMARY KEY,
        space_id TEXT NOT NULL,
        media_id TEXT,
        canonical_url TEXT,
        title TEXT,
        thumbnail_url TEXT,
        opened_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_accessed_at INTEGER NOT NULL,
        scroll_offset REAL,
        state_json TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_closed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_records(id) ON DELETE SET NULL
      )
    ''');

    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_detail_tabs_space
      ON detail_tabs(space_id, is_closed, sort_order, updated_at DESC)
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS session_snapshot (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        active_space_id TEXT,
        active_detail_tab_id TEXT,
        updated_at INTEGER NOT NULL,
        schema_version INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS migration_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createNavigationSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS spaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        feed_type TEXT NOT NULL DEFAULT 'home',
        feed_page INTEGER,
        feed_state_json TEXT,
        search_query TEXT,
        filter_state_json TEXT,
        scroll_offset REAL,
        active_detail_tab_id TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_spaces_order
      ON spaces(sort_order, updated_at DESC)
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS detail_tabs (
        id TEXT PRIMARY KEY,
        space_id TEXT NOT NULL,
        media_id TEXT,
        canonical_url TEXT,
        title TEXT,
        thumbnail_url TEXT,
        opened_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_accessed_at INTEGER NOT NULL,
        scroll_offset REAL,
        state_json TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_closed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_records(id) ON DELETE SET NULL
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_detail_tabs_space
      ON detail_tabs(space_id, is_closed, sort_order, updated_at DESC)
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS session_snapshot (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        active_space_id TEXT,
        active_detail_tab_id TEXT,
        updated_at INTEGER NOT NULL,
        schema_version INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _migrate(int from, int to) async {
    await transaction(() async {
      var version = from;
      // Keep each future schema step explicit and transaction-safe.
      while (version < to) {
        switch (version) {
          case 1:
            await _createNavigationSchema();
            version = 2;
            break;
          default:
            throw StateError('No migration registered from schema $version.');
        }
      }
      await customStatement('PRAGMA user_version = $currentSchemaVersion');
    });
  }
}

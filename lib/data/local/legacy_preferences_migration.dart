import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/models/gif_item.dart';
import 'local_database.dart';
import 'local_media_repository.dart';
import 'media_identity.dart';
import 'models/media_record.dart';

class LegacyPreferencesMigration {
  LegacyPreferencesMigration(this.database, this.repository);

  final LocalDatabase database;
  final LocalMediaRepository repository;

  static const _migrationKey = 'legacy_preferences_v1';

  Future<void> run(SharedPreferences preferences) async {
    final marker = await database.customSelect(
      'SELECT value FROM migration_state WHERE key = ? LIMIT 1',
      variables: [Variable.withString(_migrationKey)],
    ).get();

    if (marker.isNotEmpty && marker.single.read<String>('value') == 'complete') {
      return;
    }

    final likedOk = await _importList(
      preferences.getString('liked_gifs'),
      collectionName: 'Liked GIFs',
    );
    final viewedOk = await _importList(
      preferences.getString('viewed_gifs'),
      collectionName: 'Viewed GIFs',
    );

    if (likedOk && viewedOk) {
      await database.customInsert(
        '''
        INSERT INTO migration_state(key, value) VALUES (?, 'complete')
        ON CONFLICT(key) DO UPDATE SET value = 'complete'
        ''',
        variables: [Variable.withString(_migrationKey)],
      );
    }
  }

  Future<bool> _importList(
    String? jsonString, {
    required String collectionName,
  }) async {
    if (jsonString == null || jsonString.trim().isEmpty) return true;

    late final dynamic decoded;
    try { decoded = json.decode(jsonString); } catch (_) { return false; }
    if (decoded is! List) return false;

    final collectionId = MediaIdentity.fromUrls(
      mediaUrl: 'legacy-collection:$collectionName',
    );

    if (await repository.getCollection(collectionId) == null) {
      await repository.createCollection(
        collectionName,
        id: collectionId,
      );
    }

    for (final raw in decoded) {
      if (raw is! Map) continue;

      late final GifItem gif;
      try { gif = GifItem.fromMap(Map<String, dynamic>.from(raw)); } catch (_) { continue; }
      final mediaUrl = (gif.imageUrl ?? gif.url ?? '').trim();
      if (mediaUrl.isEmpty) continue;

      final sourceUrl = (gif.url ?? mediaUrl).trim();
      final id = MediaIdentity.fromUrls(
        mediaUrl: mediaUrl,
        sourceUrl: sourceUrl,
      );
      final searchText = [
        gif.title,
        gif.altText,
        sourceUrl,
        mediaUrl,
      ].whereType<String>().join(' ').toLowerCase();

      final viewedAt = gif.isViewed ? gif.timestamp : null;
      final record = MediaRecord(
        id: id,
        sourceUrl: sourceUrl,
        mediaUrl: mediaUrl,
        thumbnailUrl: gif.previewUrl,
        title: gif.title,
        width: gif.width,
        height: gif.height,
        searchText: searchText,
        createdAt: gif.timestamp,
        updatedAt: DateTime.now(),
        lastViewedAt: viewedAt,
        lastSeenAt: gif.timestamp,
      );

      await repository.addToCollection(
        collectionId: collectionId,
        media: record,
      );
    }
    return true;
  }
}

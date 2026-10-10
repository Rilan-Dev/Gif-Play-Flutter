import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gif_play/data/cache/media_cache_manager.dart';
import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
import 'package:gif_play/data/local/models/media_record.dart';


void main() {
  test('queue-originated media is persisted before its cache entry', () async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    final tempDirectory =
        await Directory.systemTemp.createTemp('gif_play_cache_test_');
    final client = MockClient((request) async => http.Response.bytes(
          <int>[71, 73, 70, 56, 57, 97],
          200,
        ));

    try {
      await database.initialize();
      final repository = LocalMediaRepository(database);
      final manager = MediaCacheManager(
        repository,
        client: client,
        cacheDirectoryProvider: () async => tempDirectory,
        maxRetries: 0,
      );
      final media = MediaRecord(
        id: 'url:https://cdn.example.test/gifs/queued.gif',
        sourceUrl: 'https://example.test/post/queued',
        mediaUrl: 'https://cdn.example.test/gifs/queued.gif',
        title: 'Queued GIF',
        searchText: 'queued gif',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await manager.prepareMedia(media);

      expect(result, isNotNull);
      expect(await result!.file.exists(), isTrue);
      expect(await repository.getMedia(media.id), isNotNull);
      expect(await repository.getCacheEntry(media.id), isNotNull);
    } finally {
      client.close();
      await database.close();
      await tempDirectory.delete(recursive: true);
    }
  });

  group('MediaCacheManager.cacheFileNameForMediaId', () {
    test('converts URL-shaped legacy IDs into safe cache filenames', () {
      final fileName = MediaCacheManager.cacheFileNameForMediaId(
        'url:https://cdn.example.test/gifs/funny.gif?size=large',
      );

      expect(fileName, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(fileName, isNot(contains('/')));
      expect(fileName, isNot(contains(':')));
      expect(fileName, isNot(contains('?')));
    });

    test('returns the same filename for the same media ID', () {
      const id = 'img:https://cdn.example.test/gifs/funny.gif';

      expect(
        MediaCacheManager.cacheFileNameForMediaId(id),
        MediaCacheManager.cacheFileNameForMediaId(id),
      );
    });

    test('keeps different media IDs in separate cache files', () {
      expect(
        MediaCacheManager.cacheFileNameForMediaId('gif-one'),
        isNot(MediaCacheManager.cacheFileNameForMediaId('gif-two')),
      );
    });
  });
}

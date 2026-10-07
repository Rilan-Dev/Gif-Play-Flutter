import 'dart:io';

import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/local/legacy_preferences_migration.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
import 'package:gif_play/data/local/media_identity.dart';
import 'package:gif_play/data/local/models/collection_item.dart';
import 'package:gif_play/data/local/models/media_record.dart';

void main() {
  late LocalDatabase database;
  late LocalMediaRepository repository;

  setUp(() async {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    repository = LocalMediaRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  MediaRecord media(int index) {
    final mediaUrl = 'https://example.com/gifs/$index.gif';
    final id = MediaIdentity.fromUrls(mediaUrl: mediaUrl);
    return MediaRecord(
      id: id,
      sourceUrl: 'https://example.com/post/$index',
      mediaUrl: mediaUrl,
      thumbnailUrl: 'https://example.com/thumbs/$index.jpg',
      title: 'GIF $index',
      sourceName: 'example',
      searchText: 'gif $index example',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      lastSeenAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('canonical identity is deterministic and removes tracking parameters', () {
    final a = MediaIdentity.fromUrls(
      mediaUrl: 'HTTPS://Example.com/a.gif?utm_source=x&b=2&a=1',
    );
    final b = MediaIdentity.fromUrls(
      mediaUrl: 'https://example.com/a.gif?a=1&b=2',
    );
    expect(a, b);
    expect(a, hasLength(64));
  });

  test('500 media records persist and remain queryable', () async {
    for (var i = 0; i < 500; i++) {
      await repository.upsertMedia(media(i));
    }

    expect(await repository.countMedia(), 500);
    final results = await repository.searchMedia('gif 499', limit: 10);
    expect(results, hasLength(1));
    expect(results.single.title, 'GIF 499');
  });

  test('collections are independent and remain after sharing', () async {
    final a = await repository.createCollection('A');
    final b = await repository.createCollection('B');
    final c = await repository.createCollection('C');

    for (var i = 0; i < 50; i++) {
      await repository.addToCollection(collectionId: a.id, media: media(i));
    }
    for (var i = 50; i < 150; i++) {
      await repository.addToCollection(collectionId: b.id, media: media(i));
    }
    for (var i = 150; i < 210; i++) {
      await repository.addToCollection(collectionId: c.id, media: media(i));
    }

    expect(await repository.countCollectionItems(a.id, pendingOnly: true), 50);
    expect(await repository.countCollectionItems(b.id, pendingOnly: true), 100);
    expect(await repository.countCollectionItems(c.id, pendingOnly: true), 60);

    final aItems = await repository.listCollectionItems(a.id, pendingOnly: true);
    await repository.markCollectionItemsShared(
      a.id,
      aItems.map((item) => item.mediaId),
    );

    expect(await repository.countCollectionItems(a.id, pendingOnly: true), 0);
    expect(await repository.countCollectionItems(b.id, pendingOnly: true), 100);
    expect(await repository.countCollectionItems(c.id, pendingOnly: true), 60);
    expect((await repository.getCollection(a.id))!.name, 'A');

    await repository.addToCollection(collectionId: a.id, media: media(499));
    expect(await repository.countCollectionItems(a.id, pendingOnly: true), 1);
  });

  test('adding the same media twice does not duplicate collection membership', () async {
    final collection = await repository.createCollection('Favorites');
    final item = media(1);

    await repository.addToCollection(collectionId: collection.id, media: item);
    await repository.addToCollection(collectionId: collection.id, media: item);

    expect(await repository.countCollectionItems(collection.id), 1);
  });
  test('collection media join returns the durable media records', () async {
    final collection = await repository.createCollection('Favorites');
    await repository.addToCollection(collectionId: collection.id, media: media(1));
    await repository.addToCollection(collectionId: collection.id, media: media(2));

    final records = await repository.listCollectionMedia(collection.id);
    expect(records.map((item) => item.title), ['GIF 1', 'GIF 2']);
  });

  test('cache state helpers track ready items without downloading binaries', () async {
    final collection = await repository.createCollection('Ready');
    await repository.addToCollection(collectionId: collection.id, media: media(1));

    await repository.updateCollectionItemCacheState(
      collectionId: collection.id,
      mediaId: media(1).id,
      cacheState: CollectionCacheState.ready,
    );

    final ready = await repository.listReadyCollectionItems(collection.id);
    expect(ready, hasLength(1));
    expect(ready.single.mediaId, media(1).id);
  });

  test('database survives close and reopen with collection state intact', () async {
    final directory = await Directory.systemTemp.createTemp('gif_play_test_');
    final path = File('${directory.path}/library.sqlite').path;
    try {
      final first = LocalDatabase.forTesting(NativeDatabase(File(path)));
      await first.initialize();
      final firstRepository = LocalMediaRepository(first);
      final collection = await firstRepository.createCollection('Persistent');
      await firstRepository.addToCollection(collectionId: collection.id, media: media(7));
      await first.close();

      final second = LocalDatabase.forTesting(NativeDatabase(File(path)));
      await second.initialize();
      final secondRepository = LocalMediaRepository(second);
      expect(await secondRepository.countMedia(), 1);
      expect(await secondRepository.countCollectionItems(collection.id), 1);
      expect((await secondRepository.getCollection(collection.id))!.name, 'Persistent');
      await second.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('legacy migration is idempotent and preserves reusable collections', () async {
    SharedPreferences.setMockInitialValues({
      'liked_gifs': '[{"id":"legacy-1","url":"https://example.com/post/1","title":"Legacy","imageUrl":"https://example.com/gifs/1.gif","timestamp":1767225600000}]',
      'viewed_gifs': '[{"id":"legacy-2","url":"https://example.com/post/2","title":"Viewed","imageUrl":"https://example.com/gifs/2.gif","timestamp":1767225600000,"isViewed":true}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final migration = LegacyPreferencesMigration(database, repository);

    await migration.run(prefs);
    await migration.run(prefs);

    final collections = await repository.listCollections();
    expect(collections.map((item) => item.name), containsAll(['Liked GIFs', 'Viewed GIFs']));
    final liked = collections.singleWhere((item) => item.name == 'Liked GIFs');
    final viewed = collections.singleWhere((item) => item.name == 'Viewed GIFs');
    expect(await repository.countCollectionItems(liked.id), 1);
    expect(await repository.countCollectionItems(viewed.id), 1);
  });
}

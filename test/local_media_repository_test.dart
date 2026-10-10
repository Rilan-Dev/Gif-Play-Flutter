import 'dart:io';

import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/cache/media_cache_manager.dart';
import 'package:gif_play/data/cache/collection_share_service.dart';
import 'package:gif_play/data/cache/collection_share_controller.dart';
import 'package:gif_play/data/local/legacy_preferences_migration.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
import 'package:gif_play/data/local/media_identity.dart';
import 'package:gif_play/data/local/models/collection_item.dart';
import 'package:gif_play/data/local/models/media_cache_entry.dart';
import 'package:gif_play/data/local/models/media_record.dart';
import 'package:gif_play/data/local/models/space.dart';
import 'package:gif_play/data/local/models/detail_tab.dart';
import 'package:gif_play/data/local/session_navigation_controller.dart';

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

  test('session controller restores and persists active space and detail tab',
      () async {
    final controller = SessionNavigationController(repository);
    await controller.load();

    expect(controller.spaces, hasLength(1));
    expect(controller.spaces.single.name, 'Home');

    final space = await controller.createSpace(name: 'Browse');
    await repository.upsertMedia(media(31));
    final tab = await controller.openDetailTab(
      spaceId: space.id,
      mediaId: media(31).id,
      canonicalUrl: media(31).sourceUrl,
      title: media(31).title,
    );

    expect(controller.activeSpaceId, space.id);
    expect(controller.activeDetailTabId, tab!.id);

    final restored = SessionNavigationController(repository);
    await restored.load();

    expect(restored.activeSpaceId, space.id);
    expect(restored.activeDetailTabId, tab.id);
    expect(restored.activeDetailTab!.mediaId, media(31).id);
  });

  test('opening the same GIF twice creates separate child tabs', () async {
    final controller = SessionNavigationController(repository);
    await controller.load();
    final space = controller.activeSpaceId!;

    final first = await controller.openDetailTab(
      spaceId: space,
      mediaId: media(91).id,
      canonicalUrl: media(91).sourceUrl,
      title: 'GIF 91',
      thumbnailUrl: media(91).thumbnailUrl,
    );
    final second = await controller.openDetailTab(
      spaceId: space,
      mediaId: media(91).id,
      canonicalUrl: media(91).sourceUrl,
      title: 'GIF 91 again',
      thumbnailUrl: media(91).thumbnailUrl,
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.id, isNot(second!.id));
    expect(controller.tabsForSpace(space), hasLength(2));
    expect(controller.activeDetailTabId, second.id);
  });

  test('switching Spaces restores each Space active child tab', () async {
    final controller = SessionNavigationController(repository);
    await controller.load();
    final firstSpaceId = controller.activeSpaceId!;
    final firstTab = await controller.openDetailTab(
      spaceId: firstSpaceId,
      mediaId: media(92).id,
      canonicalUrl: media(92).sourceUrl,
      title: 'First Space tab',
    );
    final secondSpace = await controller.createSpace(name: 'Second');
    final secondTab = await controller.openDetailTab(
      spaceId: secondSpace.id,
      mediaId: media(93).id,
      canonicalUrl: media(93).sourceUrl,
      title: 'Second Space tab',
    );

    await controller.activateSpace(firstSpaceId);
    expect(controller.activeDetailTabId, firstTab!.id);
    await controller.activateSpace(secondSpace.id);
    expect(controller.activeDetailTabId, secondTab!.id);
  });

  test('schema v1 migrates forward to persistent navigation tables', () async {
    final executor = NativeDatabase.memory();
    final legacy = LocalDatabase.forTesting(executor);
    await legacy.customStatement(
      'CREATE TABLE migration_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await legacy.customStatement('PRAGMA user_version = 1');

    await legacy.initialize();

    final spaces = await legacy.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'spaces'",
    ).get();
    final tabs = await legacy.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'detail_tabs'",
    ).get();
    final session = await legacy.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'session_snapshot'",
    ).get();

    expect(spaces, isNotEmpty);
    expect(tabs, isNotEmpty);
    expect(session, isNotEmpty);
    await legacy.close();
  });

  test('spaces, detail tabs, and session snapshot persist independently',
      () async {
    final space = await repository.createSpace(name: 'Home');
    await repository.upsertMedia(media(21));
    final tab = await repository.createDetailTab(
      spaceId: space.id,
      mediaId: media(21).id,
      canonicalUrl: media(21).sourceUrl,
      title: media(21).title,
      thumbnailUrl: media(21).thumbnailUrl,
    );
    await repository.updateSpace(
      id: space.id,
      searchQuery: 'cats',
      scrollOffset: 42.5,
      activeDetailTabId: tab.id,
    );
    await repository.saveSessionSnapshot(
      activeSpaceId: space.id,
      activeDetailTabId: tab.id,
    );

    final restoredSpace = await repository.getSpace(space.id);
    final restoredTabs = await repository.listDetailTabs(space.id);
    final snapshot = await repository.getSessionSnapshot();

    expect(restoredSpace!.searchQuery, 'cats');
    expect(restoredSpace.scrollOffset, 42.5);
    expect(restoredSpace.activeDetailTabId, tab.id);
    expect(restoredTabs, hasLength(1));
    expect(restoredTabs.single.mediaId, media(21).id);
    expect(snapshot!.activeSpaceId, space.id);
    expect(snapshot.activeDetailTabId, tab.id);

    await repository.closeDetailTab(tab.id);
    expect((await repository.listDetailTabs(space.id)), isEmpty);
    final spaceAfterClose = await repository.getSpace(space.id);
    expect(spaceAfterClose, isNotNull);
    expect(spaceAfterClose!.activeDetailTabId, isNull);
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
  test('cache eviction removes oldest ready files until byte budget is met', () async {
    final directory = await Directory.systemTemp.createTemp('gif_cache_test_');
    try {
      final oldFile = File('${directory.path}/old.bin');
      final newFile = File('${directory.path}/new.bin');
      await oldFile.writeAsBytes(List<int>.filled(80, 1));
      await newFile.writeAsBytes(List<int>.filled(80, 2));
      final old = DateTime.utc(2026, 1, 1);
      await repository.upsertCacheEntry(MediaCacheEntry(
        mediaId: media(1).id, localPath: oldFile.path, byteSize: 80,
        downloadedAt: old, lastAccessedAt: old, status: MediaCacheStatus.ready,
      ));
      await repository.upsertCacheEntry(MediaCacheEntry(
        mediaId: media(2).id, localPath: newFile.path, byteSize: 80,
        downloadedAt: old.add(const Duration(days: 1)),
        lastAccessedAt: old.add(const Duration(days: 1)),
        status: MediaCacheStatus.ready,
      ));
      await MediaCacheManager(repository, maxBytes: 80).evictIfNeeded();
      expect(await oldFile.exists(), isFalse);
      expect(await newFile.exists(), isTrue);
      expect(await repository.countCacheBytes(), 80);
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test('collection readiness aggregates pending cache states', () async {
    final collection = await repository.createCollection('Ready List');
    await repository.addToCollection(collectionId: collection.id, media: media(1));
    await repository.addToCollection(collectionId: collection.id, media: media(2));
    await repository.addToCollection(collectionId: collection.id, media: media(3));

    await repository.updateCollectionItemCacheState(
      collectionId: collection.id,
      mediaId: media(1).id,
      cacheState: CollectionCacheState.ready,
    );
    await repository.updateCollectionItemCacheState(
      collectionId: collection.id,
      mediaId: media(2).id,
      cacheState: CollectionCacheState.failed,
      error: 'network',
    );

    final readiness = await MediaCacheManager(repository)
        .getCollectionReadiness(collection.id);

    expect(readiness.total, 3);
    expect(readiness.pending, 3);
    expect(readiness.ready, 1);
    expect(readiness.failed, 1);
    expect(readiness.notCached, 1);
    expect(readiness.isReadyToShare, isFalse);
  });


  test('cache manager retries a failed download and records the ready result',
      () async {
    var attempts = 0;
    final client = _RetryClient(() {
      attempts++;
      if (attempts == 1) {
        return http.Response('temporary failure', 503);
      }
      return http.Response.bytes([1, 2, 3, 4], 200);
    });

    final manager = MediaCacheManager(
      repository,
      client: client,
      maxRetries: 1,
      retryBaseDelay: Duration.zero,
    );

    final result = await manager.prepareMedia(media(1));

    expect(result, isNotNull);
    expect(attempts, 2);
    expect(await result!.file.exists(), isTrue);
    expect((await repository.getCacheEntry(result.mediaId))!.status,
        MediaCacheStatus.ready);
  });

  test('cache cleanup removes expired and failed artifacts but preserves collections',
      () async {
    final collection = await repository.createCollection('Reusable');
    await repository.addToCollection(
      collectionId: collection.id,
      media: media(2),
    );

    final expiredPath =
        '${Directory.systemTemp.path}/gif-play-expired-${DateTime.now().microsecondsSinceEpoch}';
    final failedPath =
        '${Directory.systemTemp.path}/gif-play-failed-${DateTime.now().microsecondsSinceEpoch}';
    final expiredFile = File(expiredPath);
    final failedFile = File(failedPath);
    await expiredFile.writeAsBytes([1, 2, 3]);
    await failedFile.writeAsBytes([4, 5]);

    final now = DateTime.now();
    await repository.upsertCacheEntry(
      MediaCacheEntry(
        mediaId: media(2).id,
        localPath: expiredPath,
        byteSize: 3,
        downloadedAt: now.subtract(const Duration(days: 2)),
        lastAccessedAt: now.subtract(const Duration(days: 2)),
        expiresAt: now.subtract(const Duration(minutes: 1)),
        status: MediaCacheStatus.ready,
      ),
    );
    await repository.upsertCacheEntry(
      MediaCacheEntry(
        mediaId: media(3).id,
        localPath: failedPath,
        byteSize: 2,
        downloadedAt: now,
        lastAccessedAt: now,
        status: MediaCacheStatus.failed,
        failureCount: 2,
        lastError: 'network',
      ),
    );

    final result = await MediaCacheManager(repository).cleanup();

    expect(result.removedEntries, 2);
    expect(await expiredFile.exists(), isFalse);
    expect(await failedFile.exists(), isFalse);
    expect(await repository.getCacheEntry(media(2).id), isNull);
    expect(await repository.getCollection(collection.id), isNotNull);
    expect(await repository.countCollectionItems(collection.id), 1);
  });

  test('controller retry clears failed item state through the cache manager',
      () async {
    final collection = await repository.createCollection('Retry List');
    await repository.addToCollection(
      collectionId: collection.id,
      media: media(11),
    );

    final failingClient = _RetryClient(
      () => http.Response('temporary failure', 503),
    );
    final failingManager = MediaCacheManager(
      repository,
      client: failingClient,
      maxRetries: 0,
      retryBaseDelay: Duration.zero,
    );
    await failingManager.prepareMedia(
      media(11),
      collectionId: collection.id,
    );

    var item = (await repository.listCollectionItems(collection.id)).single;
    expect(item.cacheState, CollectionCacheState.failed);

    final successClient = _RetryClient(
      () => http.Response.bytes([7, 8, 9], 200),
    );
    final manager = MediaCacheManager(
      repository,
      client: successClient,
      maxRetries: 0,
      retryBaseDelay: Duration.zero,
    );
    final controller = CollectionShareController(
      repository,
      cacheManager: manager,
    );

    await controller.retryItem(collection.id, item.mediaId);

    item = (await repository.listCollectionItems(collection.id)).single;
    expect(item.cacheState, CollectionCacheState.ready);
    expect(controller.itemsForCollection(collection.id).single.cacheState,
        CollectionCacheState.ready);
  });

  test('collection share service never marks an unready preparation shared',
      () async {
    final collection = await repository.createCollection('Safe Share');
    await repository.addToCollection(
      collectionId: collection.id,
      media: media(12),
    );

    final readiness =
        await MediaCacheManager(repository).getCollectionReadiness(collection.id);
    final preparation = CollectionSharePreparation(
      collectionId: collection.id,
      media: [media(12)],
      cachedFiles: const [],
      readiness: readiness,
    );

    await CollectionShareService(repository).markCollectionsShared(
      [preparation],
    );

    expect(
      await repository.countCollectionItems(
        collection.id,
        pendingOnly: true,
      ),
      1,
    );
  });

  test('empty collection preparation is explicit and never share-ready',
      () async {
    final collection = await repository.createCollection('Empty');
    final preparation =
        await CollectionShareService(repository).prepareCollection(
      collection.id,
    );

    expect(preparation.isEmpty, isTrue);
    expect(preparation.hasPendingItems, isFalse);
    expect(preparation.isReadyToShare, isFalse);
  });

  test('collection share service deduplicates selected collection ids', () async {
    final first = await repository.createCollection('First');
    final second = await repository.createCollection('Second');
    final service = CollectionShareService(repository);

    final preparations = await service.prepareCollections(
      [first.id, second.id, first.id],
    );

    expect(preparations.map((item) => item.collectionId).toSet(),
        {first.id, second.id});
  });

  test('Space feed snapshot persists query, pagination, and scroll metadata',
      () async {
    final space = await repository.createSpace(name: 'Cats');
    const snapshot =
        '{"mediaItems":[{"imageUrl":"https://example.com/cat.gif","title":"Cat"}],'
        '"currentPage":3,"totalPages":12,"visitedPages":[1,3],'
        '"searchQuery":"cat","scrollOffset":246.5}';

    await repository.updateSpace(
      id: space.id,
      feedPage: 3,
      feedStateJson: snapshot,
      searchQuery: 'cat',
      scrollOffset: 246.5,
    );

    final restored = await repository.getSpace(space.id);
    expect(restored?.feedPage, 3);
    expect(restored?.feedStateJson, snapshot);
    expect(restored?.searchQuery, 'cat');
    expect(restored?.scrollOffset, 246.5);
  });


  test('legacy clear request preserves collection and saved GIF membership', () async {
    final collection = await repository.createCollection('Reusable bulk list');
    await repository.addToCollection(
      collectionId: collection.id,
      media: media(13),
    );
    await repository.markCollectionItemsShared(collection.id, [media(13).id]);

    await repository.clearCollectionItems(collection.id);

    expect(await repository.getCollection(collection.id), isNotNull);
    expect(await repository.countCollectionItems(collection.id), 1);
    expect(await repository.countCollectionItems(
      collection.id,
      pendingOnly: true,
    ), 1);
  });

}

class _RetryClient extends http.BaseClient {
  _RetryClient(this._responseFactory);

  final http.Response Function() _responseFactory;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _responseFactory();
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

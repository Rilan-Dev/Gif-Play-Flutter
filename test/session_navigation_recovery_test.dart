import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
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

  test('startup repairs a snapshot that references a closed detail tab',
      () async {
    final space = await repository.createSpace(name: 'Browse');
    final closed = await repository.createDetailTab(
      spaceId: space.id,
      canonicalUrl: 'https://example.com/closed',
      title: 'Closed tab',
      sortOrder: 0,
    );
    final remaining = await repository.createDetailTab(
      spaceId: space.id,
      canonicalUrl: 'https://example.com/open',
      title: 'Open tab',
      sortOrder: 1,
    );
    await repository.updateSpace(
      id: space.id,
      activeDetailTabId: closed.id,
    );
    await repository.saveSessionSnapshot(
      activeSpaceId: space.id,
      activeDetailTabId: closed.id,
    );
    await repository.closeDetailTab(closed.id);

    final controller = SessionNavigationController(repository);
    await controller.load();

    expect(controller.activeSpaceId, space.id);
    expect(controller.activeDetailTabId, remaining.id);
    expect(controller.activeDetailTab?.title, 'Open tab');
    final repaired = await repository.getSessionSnapshot();
    expect(repaired?.activeDetailTabId, remaining.id);
  });

  test('startup never restores a detail tab belonging to another Space',
      () async {
    final firstSpace = await repository.createSpace(name: 'First');
    final secondSpace = await repository.createSpace(name: 'Second');
    final firstTab = await repository.createDetailTab(
      spaceId: firstSpace.id,
      canonicalUrl: 'https://example.com/first',
      title: 'First tab',
    );
    final secondTab = await repository.createDetailTab(
      spaceId: secondSpace.id,
      canonicalUrl: 'https://example.com/second',
      title: 'Second tab',
    );
    await repository.updateSpace(
      id: secondSpace.id,
      activeDetailTabId: secondTab.id,
    );
    await repository.saveSessionSnapshot(
      activeSpaceId: secondSpace.id,
      activeDetailTabId: firstTab.id,
    );

    final controller = SessionNavigationController(repository);
    await controller.load();

    expect(controller.activeSpaceId, secondSpace.id);
    expect(controller.activeDetailTabId, secondTab.id);
    expect(controller.activeDetailTab?.spaceId, secondSpace.id);
    expect((await repository.getSessionSnapshot())?.activeDetailTabId,
        secondTab.id);
  });

  test('Spaces, Detail Tabs, and session snapshot survive database reopen',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('gif_play_navigation_reopen_');
    final path = '${directory.path}/library.sqlite';
    try {
      final first = LocalDatabase.forTesting(NativeDatabase(File(path)));
      await first.initialize();
      final firstRepository = LocalMediaRepository(first);
      final space = await firstRepository.createSpace(name: 'Persistent Space');
      final tab = await firstRepository.createDetailTab(
        spaceId: space.id,
        canonicalUrl: 'https://example.com/persistent',
        title: 'Persistent GIF',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        sortOrder: 0,
      );
      await firstRepository.updateSpace(
        id: space.id,
        searchQuery: 'cats',
        scrollOffset: 123.5,
        activeDetailTabId: tab.id,
      );
      await firstRepository.saveSessionSnapshot(
        activeSpaceId: space.id,
        activeDetailTabId: tab.id,
      );
      await first.close();

      final second = LocalDatabase.forTesting(NativeDatabase(File(path)));
      await second.initialize();
      final secondRepository = LocalMediaRepository(second);
      final restoredSpace = await secondRepository.getSpace(space.id);
      final restoredTabs = await secondRepository.listDetailTabs(space.id);
      final snapshot = await secondRepository.getSessionSnapshot();

      expect(restoredSpace?.name, 'Persistent Space');
      expect(restoredSpace?.searchQuery, 'cats');
      expect(restoredSpace?.scrollOffset, 123.5);
      expect(restoredTabs, hasLength(1));
      expect(restoredTabs.single.id, tab.id);
      expect(restoredTabs.single.canonicalUrl, 'https://example.com/persistent');
      expect(snapshot?.activeSpaceId, space.id);
      expect(snapshot?.activeDetailTabId, tab.id);

      await second.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

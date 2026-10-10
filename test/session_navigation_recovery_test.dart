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

  test('activating and closing tabs persists the current navigation state',
      () async {
    final controller = SessionNavigationController(repository);
    await controller.load();
    final space = controller.activeSpace!;
    final first = await controller.openDetailTab(
      spaceId: space.id,
      canonicalUrl: 'https://example.com/first',
      title: 'First',
    );
    final second = await controller.openDetailTab(
      spaceId: space.id,
      canonicalUrl: 'https://example.com/second',
      title: 'Second',
    );

    await controller.activateDetailTab(first!.id);
    expect(controller.activeDetailTabId, first.id);
    expect((await repository.getSessionSnapshot())?.activeDetailTabId,
        first.id);

    await controller.closeDetailTab(first.id);
    expect(controller.activeDetailTabId, second!.id);
    expect((await repository.getSessionSnapshot())?.activeDetailTabId,
        second.id);
    expect(controller.tabsForSpace(space.id).map((tab) => tab.id),
        contains(second.id));
    expect(controller.tabsForSpace(space.id).map((tab) => tab.id),
        isNot(contains(first.id)));
  });

  test('each Space retains an independent feed snapshot', () async {
    final firstSpace = await repository.createSpace(name: 'First feed');
    final secondSpace = await repository.createSpace(name: 'Second feed');

    await repository.updateSpace(
      id: firstSpace.id,
      feedPage: 3,
      feedStateJson: '{"mediaItems":[{"imageUrl":"https://example.com/first.gif"}],"currentPage":3}',
      searchQuery: 'cats',
      scrollOffset: 85.0,
    );
    await repository.updateSpace(
      id: secondSpace.id,
      feedPage: 7,
      feedStateJson: '{"mediaItems":[{"imageUrl":"https://example.com/second.gif"}],"currentPage":7}',
      searchQuery: 'dogs',
      scrollOffset: 240.0,
    );

    final restoredFirst = await repository.getSpace(firstSpace.id);
    final restoredSecond = await repository.getSpace(secondSpace.id);
    expect(restoredFirst?.feedPage, 3);
    expect(restoredFirst?.searchQuery, 'cats');
    expect(restoredFirst?.scrollOffset, 85.0);
    expect(restoredFirst?.feedStateJson, contains('first.gif'));
    expect(restoredSecond?.feedPage, 7);
    expect(restoredSecond?.searchQuery, 'dogs');
    expect(restoredSecond?.scrollOffset, 240.0);
    expect(restoredSecond?.feedStateJson, contains('second.gif'));
    expect(restoredFirst?.feedStateJson, isNot(contains('second.gif')));
    expect(restoredSecond?.feedStateJson, isNot(contains('first.gif')));
  });

  test('rapid concurrent Space switches leave the final Space and tab active',
      () async {
    final controller = SessionNavigationController(repository);
    await controller.load();
    final firstSpace = controller.activeSpace!;
    final firstTab = await controller.openDetailTab(
      spaceId: firstSpace.id,
      canonicalUrl: 'https://example.com/first',
      title: 'First tab',
    );
    final secondSpace = await controller.createSpace(name: 'Second Space');
    final secondTab = await controller.openDetailTab(
      spaceId: secondSpace.id,
      canonicalUrl: 'https://example.com/second',
      title: 'Second tab',
    );

    // Start several transitions before any caller awaits the previous one.
    await Future.wait([
      controller.activateSpace(firstSpace.id),
      controller.activateSpace(secondSpace.id),
      controller.activateSpace(firstSpace.id),
    ]);

    expect(controller.activeSpaceId, firstSpace.id);
    expect(controller.activeDetailTabId, firstTab!.id);
    expect(controller.activeDetailTab?.spaceId, firstSpace.id);
    final snapshot = await repository.getSessionSnapshot();
    expect(snapshot?.activeSpaceId, firstSpace.id);
    expect(snapshot?.activeDetailTabId, firstTab.id);
    expect((await repository.getSpace(firstSpace.id))?.activeDetailTabId,
        firstTab.id);
    expect((await repository.getSpace(secondSpace.id))?.activeDetailTabId,
        secondTab!.id);
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

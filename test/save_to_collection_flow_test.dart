import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gif_play/common/models/gif_item.dart';
import 'package:gif_play/common/models/media_item.dart';
import 'package:gif_play/common/providers/liked_gifs_provider.dart';
import 'package:gif_play/common/providers/share_queue_provider.dart';
import 'package:gif_play/common/utils/shared_preferences_util.dart';
import 'package:gif_play/data/cache/collection_share_controller.dart';
import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
import 'package:gif_play/data/local/session_navigation_controller.dart';
import 'package:gif_play/screens/main_screen/main_screen_actions.dart';

void main() {
  testWidgets('GIF Details can create a collection and save a selected GIF',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    SharedPreferencesUtil.init(await SharedPreferences.getInstance());

    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    final repository = LocalMediaRepository(database);
    final navigation = SessionNavigationController(repository);
    await navigation.load();
    final liked = LikedGifsProvider(repository);
    await liked.loadLikedGifs();
    final shareQueue = ShareQueueProvider();
    await shareQueue.loadQueuedGifs();
    final collections = CollectionShareController(repository);
    await collections.loadCollections();

    final item = MediaItem(
      imageUrl: 'https://example.test/parent.gif',
      title: 'Parent GIF',
      href: 'https://example.test/post/parent',
    );
    final suggestion = GifItem(
      id: 'suggestion-1',
      url: 'https://example.test/suggestion.gif',
      imageUrl: 'https://example.test/suggestion.gif',
      title: 'Suggested GIF',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionNavigationController>.value(
            value: navigation,
          ),
          ChangeNotifierProvider<LikedGifsProvider>.value(value: liked),
          ChangeNotifierProvider<ShareQueueProvider>.value(value: shareQueue),
          ChangeNotifierProvider<CollectionShareController>.value(
            value: collections,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MainScreenActions.showGifDetailsDialog(
                  context,
                  item,
                  suggestionLoader: (_) async => [suggestion],
                ),
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('GIF Details'), findsOneWidget);
    expect(find.text('Suggested GIF'), findsOneWidget);

    await tester.ensureVisible(find.text('Save to collection'));
    await tester.tap(find.text('Save to collection'));
    await tester.pump();
    await tester.tap(find.text('New collection'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'My saved GIFs');
    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('My saved GIFs'), findsOneWidget);
    await tester.tap(find.text('My saved GIFs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final savedCollection = (await repository.listCollections())
        .singleWhere((collection) => collection.name == 'My saved GIFs');
    expect(await repository.countCollectionItems(savedCollection.id), 1);
    expect(
      (await repository.listCollectionMedia(savedCollection.id)).single.title,
      'Suggested GIF',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gif_play/common/models/media_item.dart';
import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
import 'package:gif_play/data/local/session_navigation_controller.dart';
import 'package:gif_play/screens/main_screen/main_screen_actions.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('opening a regular feed item activates a persistent Detail Tab',
      (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    final controller = SessionNavigationController(
      LocalMediaRepository(database),
    );
    await controller.load();
    final item = MediaItem(
      imageUrl: 'https://example.com/preview.gif',
      title: 'Example GIF',
      href: 'https://example.com/post/1',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionNavigationController>.value(
        value: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => MainScreenActions.handleItemClick(
                  context,
                  item,
                  0,
                  false,
                  () {},
                  [item],
                ),
                child: const Text('Open GIF'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open GIF'));
    await tester.pumpAndSettle();

    expect(controller.activeDetailTab, isNotNull);
    expect(controller.activeDetailTab?.title, 'Example GIF');
    expect(controller.activeDetailTab?.canonicalUrl, 'https://example.com/post/1');
    expect(find.text('Open GIF'), findsOneWidget);
    expect(find.text('GIF Details'), findsNothing);

    await database.close();
  });
}

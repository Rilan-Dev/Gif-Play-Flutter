import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gif_play/common/widgets/session_navigation_strip.dart';
import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
import 'package:gif_play/data/local/session_navigation_controller.dart';

void main() {
  testWidgets('Home feed and child tabs stay accessible in the same shell',
      (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    final controller = SessionNavigationController(
      LocalMediaRepository(database),
    );
    await controller.load();
    final spaceId = controller.activeSpaceId!;
    final tab = await controller.openDetailTab(
      spaceId: spaceId,
      canonicalUrl: 'https://example.test/gif/one',
      title: 'Persistent GIF',
      thumbnailUrl: 'https://example.test/gif/one.gif',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionNavigationController>.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SessionNavigationStrip(),
                Expanded(child: Center(child: Text('Detail surface'))),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home feed'), findsOneWidget);
    expect(find.text('Persistent GIF'), findsOneWidget);
    expect(find.text('Detail surface'), findsOneWidget);

    await tester.tap(find.text('Home feed'));
    await tester.pumpAndSettle();
    expect(controller.activeDetailTabId, isNull);
    expect(controller.tabsForSpace(spaceId), hasLength(1));
    expect(find.text('Persistent GIF'), findsOneWidget);

    await tester.tap(find.text('Persistent GIF'));
    await tester.pumpAndSettle();
    expect(controller.activeDetailTabId, tab!.id);
    expect(find.text('Home feed'), findsOneWidget);

    await database.close();
  });
}

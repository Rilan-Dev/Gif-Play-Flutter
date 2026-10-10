import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:provider/provider.dart';
import 'package:gif_play/common/models/gif_item.dart';
import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
import 'package:gif_play/data/local/session_navigation_controller.dart';
import 'package:gif_play/common/widgets/detail_tab_content.dart';
import 'package:gif_play/data/local/models/detail_tab.dart';

void main() {
  DetailTab tab({String? url}) {
    final now = DateTime.utc(2026, 10, 10);
    return DetailTab(
      id: 'tab-1',
      spaceId: 'space-1',
      canonicalUrl: url,
      title: 'Saved GIF',
      thumbnailUrl: 'https://example.com/preview.gif',
      openedAt: now,
      updatedAt: now,
      lastAccessedAt: now,
    );
  }

  testWidgets('unsafe source schemes are rejected before opening externally',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailTabContent(tab: tab(url: 'javascript:alert(1)')),
        ),
      ),
    );

    await tester.tap(find.text('Open original source'));
    await tester.pump();

    expect(find.text('This source URL is invalid.'), findsOneWidget);
  });

  testWidgets('GIF options are available as an explicit detail-tab action',
      (tester) async {
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailTabContent(
            tab: tab(url: 'https://example.com/post/1'),
            onMoreOptions: () => invoked = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('GIF options'));
    expect(invoked, isTrue);

  testWidgets('choosing a suggestion opens a new persistent child tab',
      (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    final controller = SessionNavigationController(
      LocalMediaRepository(database),
    );
    await controller.load();
    final spaceId = controller.activeSpaceId!;
    final parent = await controller.openDetailTab(
      spaceId: spaceId,
      canonicalUrl: 'https://example.test/post/parent',
      title: 'Parent GIF',
      thumbnailUrl: 'https://example.test/parent.gif',
    );
    final suggestion = GifItem(
      id: 'suggestion-1',
      url: 'https://example.test/suggestion.gif',
      imageUrl: 'https://example.test/suggestion.gif',
      title: 'Suggestion GIF',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionNavigationController>.value(
        value: controller,
        child: MaterialApp(
          home: Scaffold(
            body: DetailTabContent(
              tab: parent!,
              suggestionLoader: (_) async => [suggestion],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Suggestion GIF'), findsOneWidget);

    await tester.tap(find.text('Suggestion GIF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(controller.tabsForSpace(spaceId), hasLength(2));
    expect(controller.activeDetailTab?.title, 'Suggestion GIF');
    expect(controller.activeDetailTab?.id, isNot(parent.id));

    await database.close();
  });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}

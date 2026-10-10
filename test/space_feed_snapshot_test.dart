import 'package:flutter_test/flutter_test.dart';
import 'package:gif_play/screens/main_screen/space_feed_snapshot.dart';

void main() {
  test('empty saved feed requests a fresh feed fetch', () {
    final snapshot = SpaceFeedSnapshot.restore(
      feedStateJson: '{"mediaItems":[],"currentPage":4,"visitedPages":[1,2]}',
      persistedSearchQuery: 'cats',
      persistedScrollOffset: 75,
      persistedPage: 4,
    );

    expect(snapshot.mediaItems, isEmpty);
    expect(snapshot.requiresFetch, isTrue);
    expect(snapshot.currentPage, 4);
    expect(snapshot.visitedPages, {1, 2});
    expect(snapshot.searchQuery, 'cats');
    expect(snapshot.scrollOffset, 75);
  });

  test('missing or malformed saved feed safely requests a fresh fetch', () {
    for (final state in <String?>[null, '', '{not valid json']) {
      final snapshot = SpaceFeedSnapshot.restore(feedStateJson: state);
      expect(snapshot.mediaItems, isEmpty);
      expect(snapshot.requiresFetch, isTrue);
      expect(snapshot.currentPage, 1);
      expect(snapshot.scrollOffset, 0);
    }
  });

  test('valid saved feed restores lightweight items and avoids refetch', () {
    final snapshot = SpaceFeedSnapshot.restore(
      feedStateJson:
          '{"mediaItems":[{"imageUrl":"https://example.com/cat.gif","title":"Cat"}],"currentPage":2,"totalPages":12,"visitedPages":[1,2],"scrollOffset":33}',
    );

    expect(snapshot.mediaItems, hasLength(1));
    expect(snapshot.mediaItems.single.title, 'Cat');
    expect(snapshot.requiresFetch, isFalse);
    expect(snapshot.currentPage, 2);
    expect(snapshot.totalPages, 12);
    expect(snapshot.visitedPages, {1, 2});
    expect(snapshot.scrollOffset, 33);
  });

  test('invalid media entries are dropped and the snapshot stays bounded', () {
    final media = List.generate(
      125,
      (index) => '{"imageUrl":"https://example.com/$index.gif"}',
    ).join(',');
    final snapshot = SpaceFeedSnapshot.restore(
      feedStateJson: '{"mediaItems":[{"title":"missing image"},$media]}',
    );

    expect(snapshot.mediaItems, hasLength(120));
    expect(snapshot.mediaItems.every((item) => item.imageUrl.isNotEmpty), isTrue);
    expect(snapshot.requiresFetch, isFalse);
  });
}

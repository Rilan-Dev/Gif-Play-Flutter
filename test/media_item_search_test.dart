import 'package:flutter_test/flutter_test.dart';
import 'package:gif_play/common/models/media_item.dart';
import 'package:gif_play/screens/main_screen/media_item_search.dart';

void main() {
  test('search matches GIF title without case sensitivity', () {
    final item = MediaItem(
      imageUrl: 'https://cdn.example.test/assets/123.gif',
      title: 'Funny Cat',
      href: 'https://example.test/post/1',
    );
    expect(mediaItemMatchesQuery(item, 'FUNNY'), isTrue);
  });

  test('search matches source and image URLs', () {
    final item = MediaItem(
      imageUrl: 'https://cdn.example.test/assets/cat-dance.gif',
      title: 'Dancing',
      href: 'https://example.test/post/abc123',
    );
    expect(mediaItemMatchesQuery(item, 'abc123'), isTrue);
    expect(mediaItemMatchesQuery(item, 'cat-dance'), isTrue);
  });

  test('empty or whitespace query keeps all items', () {
    final item = MediaItem(
      imageUrl: 'https://cdn.example.test/anything.gif',
      title: 'Any GIF',
    );
    expect(mediaItemMatchesQuery(item, ''), isTrue);
    expect(mediaItemMatchesQuery(item, '   '), isTrue);
  });

  test('search does not match unrelated terms', () {
    final item = MediaItem(
      imageUrl: 'https://cdn.example.test/one.gif',
      title: 'One GIF',
      href: 'https://example.test/one',
    );
    expect(mediaItemMatchesQuery(item, 'not-found'), isFalse);
  });
}

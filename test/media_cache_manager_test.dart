import 'package:flutter_test/flutter_test.dart';
import 'package:gif_play/data/cache/media_cache_manager.dart';

void main() {
  group('MediaCacheManager.cacheFileNameForMediaId', () {
    test('converts URL-shaped legacy IDs into safe cache filenames', () {
      final fileName = MediaCacheManager.cacheFileNameForMediaId(
        'url:https://cdn.example.test/gifs/funny.gif?size=large',
      );

      expect(fileName, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(fileName, isNot(contains('/')));
      expect(fileName, isNot(contains(':')));
      expect(fileName, isNot(contains('?')));
    });

    test('returns the same filename for the same media ID', () {
      const id = 'img:https://cdn.example.test/gifs/funny.gif';

      expect(
        MediaCacheManager.cacheFileNameForMediaId(id),
        MediaCacheManager.cacheFileNameForMediaId(id),
      );
    });

    test('keeps different media IDs in separate cache files', () {
      expect(
        MediaCacheManager.cacheFileNameForMediaId('gif-one'),
        isNot(MediaCacheManager.cacheFileNameForMediaId('gif-two')),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gif_play/common/models/gif_item.dart';
import 'package:gif_play/common/providers/share_queue_provider.dart';
import 'package:gif_play/common/utils/shared_preferences_util.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesUtil.init(await SharedPreferences.getInstance());
  });

  test('share queue survives provider recreation', () async {
    final first = ShareQueueProvider();
    await first.loadQueuedGifs();
    first.addGifs([
      GifItem(
        id: 'gif-one',
        url: 'https://example.test/post/one',
        imageUrl: 'https://cdn.example.test/one.gif',
        title: 'First GIF',
      ),
      GifItem(
        id: 'gif-two',
        url: 'https://example.test/post/two',
        imageUrl: 'https://cdn.example.test/two.gif',
        title: 'Second GIF',
      ),
    ]);
    await first.flushPersistence();

    final restored = ShareQueueProvider();
    await restored.loadQueuedGifs();

    expect(restored.queuedGifs, hasLength(2));
    expect(restored.queuedGifs.map((gif) => gif.id),
        containsAll(['gif-one', 'gif-two']));
  });

  test('removing and clearing queue entries persists the new state', () async {
    final first = ShareQueueProvider();
    await first.loadQueuedGifs();
    final gif = GifItem(
      id: 'gif-one',
      url: 'https://example.test/post/one',
      imageUrl: 'https://cdn.example.test/one.gif',
      title: 'First GIF',
    );
    first.addGif(gif);
    await first.flushPersistence();
    first.removeGif(gif);
    await first.flushPersistence();

    final restored = ShareQueueProvider();
    await restored.loadQueuedGifs();
    expect(restored.queuedGifs, isEmpty);
  });
}

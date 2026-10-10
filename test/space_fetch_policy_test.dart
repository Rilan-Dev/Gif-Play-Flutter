import 'package:flutter_test/flutter_test.dart';
import 'package:gif_play/screens/main_screen/space_fetch_policy.dart';

void main() {
  test('queues a fetch for a newly active Space during another fetch', () {
    expect(
      pendingSpaceForOverlappingFetch(
        expectedSpaceId: null,
        activeSpaceId: 'space-b',
        lastSpaceId: 'space-b',
        activeFetchSpaceId: 'space-a',
      ),
      'space-b',
    );
  });

  test('does not queue duplicate requests for the Space already fetching', () {
    expect(
      pendingSpaceForOverlappingFetch(
        expectedSpaceId: null,
        activeSpaceId: 'space-a',
        lastSpaceId: 'space-a',
        activeFetchSpaceId: 'space-a',
      ),
      isNull,
    );
  });

  test('explicit restore target takes priority over stale screen state', () {
    expect(
      pendingSpaceForOverlappingFetch(
        expectedSpaceId: 'space-c',
        activeSpaceId: 'space-b',
        lastSpaceId: 'space-a',
        activeFetchSpaceId: 'space-a',
      ),
      'space-c',
    );
  });

  test('returns null when there is no identifiable requested Space', () {
    expect(
      pendingSpaceForOverlappingFetch(
        expectedSpaceId: null,
        activeSpaceId: null,
        lastSpaceId: null,
        activeFetchSpaceId: null,
      ),
      isNull,
    );
  });
}

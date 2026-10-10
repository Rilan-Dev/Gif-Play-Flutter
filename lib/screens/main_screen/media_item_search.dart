import '../../common/models/media_item.dart';

/// Case-insensitive local search across the visible GIF title and its URLs.
bool mediaItemMatchesQuery(MediaItem item, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;

  return [
    item.title,
    item.href,
    item.imageUrl,
  ].whereType<String>().any(
        (value) => value.toLowerCase().contains(normalized),
      );
}

import 'dart:convert';

/// A model representing a media item.
///
/// This class provides a consistent structure for media items across the app,
/// with support for serialization and deserialization.
class MediaItem {
  final String imageUrl;
  final String? title;
  final String? href;
  final DateTime? timestamp;

  MediaItem({
    required this.imageUrl,
    this.title,
    this.href,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'href': href,
      'timestamp': timestamp?.millisecondsSinceEpoch,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      imageUrl: map['imageUrl'] ?? '',
      title: map['title'],
      href: map['href'],
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) 
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MediaItem.fromJson(String source) => MediaItem.fromMap(json.decode(source));

  MediaItem copyWith({
    String? imageUrl,
    String? title,
    String? href,
    DateTime? timestamp,
  }) {
    return MediaItem(
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      href: href ?? this.href,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'MediaItem(imageUrl: $imageUrl, title: $title, href: $href, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem && 
           other.imageUrl == imageUrl && 
           other.title == title && 
           other.href == href;
  }

  @override
  int get hashCode {
    return imageUrl.hashCode ^ title.hashCode ^ href.hashCode;
  }
}


import 'dart:convert';

/// A model representing a GIF item.
///
/// This class provides a consistent structure for GIF items across the app,
/// with support for serialization and deserialization.
class GifItem {
  final String? id;
  final String? url;
  final String title;
  final String? previewUrl;
  final DateTime timestamp;
  final bool isViewed;
  final String? imageUrl;
  final String? altText;
  final int? width;
  final int? height;

  GifItem({
    this.id,
    this.url,
    required this.title,
    this.previewUrl,
    DateTime? timestamp,
    this.isViewed = false,
    this.imageUrl,
    this.altText,
    this.width,
    this.height,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'previewUrl': previewUrl,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isViewed': isViewed,
      'imageUrl': imageUrl,
      'altText': altText,
      'width': width,
      'height': height,
    };
  }

  factory GifItem.fromMap(Map<String, dynamic> map) {
    return GifItem(
      id: map['id'],
      url: map['url'],
      title: map['title'] ?? '',
      previewUrl: map['previewUrl'],
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) 
          : DateTime.now(),
      isViewed: map['isViewed'] ?? false,
      imageUrl: map['imageUrl'],
      altText: map['altText'],
      width: map['width'],
      height: map['height'],
    );
  }

  String toJson() => json.encode(toMap());

  factory GifItem.fromJson(String source) => GifItem.fromMap(json.decode(source));

  GifItem copyWith({
    String? id,
    String? url,
    String? title,
    String? previewUrl,
    DateTime? timestamp,
    bool? isViewed,
    String? imageUrl,
    String? altText,
    int? width,
    int? height,
  }) {
    return GifItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      previewUrl: previewUrl ?? this.previewUrl,
      timestamp: timestamp ?? this.timestamp,
      isViewed: isViewed ?? this.isViewed,
      imageUrl: imageUrl ?? this.imageUrl,
      altText: altText ?? this.altText,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  String toString() {
    return 'GifItem(id: $id, url: $url, title: $title, previewUrl: $previewUrl, timestamp: $timestamp, isViewed: $isViewed, imageUrl: $imageUrl, altText: $altText, width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GifItem && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}


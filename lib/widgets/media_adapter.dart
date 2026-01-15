import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../common/models/media_item.dart';

class MediaAdapter extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem, int) onItemClick;
  final Function(MediaItem, int)? onItemLongClick;

  const MediaAdapter({
    Key? key,
    required this.mediaItems,
    required this.onItemClick,
    this.onItemLongClick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: mediaItems.length,
      itemBuilder: (context, index) {
        final item = mediaItems[index];
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            leading: SizedBox(
              width: 60,
              height: 60,
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            title: Text(item.title ?? 'No Title'),
            subtitle: Text(item.href ?? 'No Link'),
            onTap: () => onItemClick(item, index),
            onLongPress: onItemLongClick != null 
                ? () => onItemLongClick!(item, index) 
                : null,
          ),
        );
      },
    );
  }
}


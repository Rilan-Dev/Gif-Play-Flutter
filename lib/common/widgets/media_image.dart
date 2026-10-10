import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'media_image_local_stub.dart'
    if (dart.library.io) 'media_image_local_io.dart' as local_image;
import 'shimmer_loading.dart';

/// Renders a media URL or a locally cached file path.
///
/// Local-file rendering is isolated behind a conditional import so this widget
/// remains compilable on Flutter Web, where dart:io is unavailable.
class MediaImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final double placeholderHeight;
  final BoxFit fit;

  const MediaImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.placeholderHeight = 200,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl);
    if (imageUrl.startsWith('/') || uri?.scheme == 'file') {
      final path = uri?.scheme == 'file' ? uri!.toFilePath() : imageUrl;
      return local_image.buildLocalImage(
        context,
        path,
        width: width,
        height: height,
        fit: fit,
      );
    }

    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => ShimmerLoading(height: placeholderHeight),
        errorWidget: (context, url, error) => Center(
          child: Icon(Icons.error, color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(Icons.image, color: Theme.of(context).disabledColor),
      ),
    );
  }
}

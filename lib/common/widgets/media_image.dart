import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'shimmer_loading.dart';

class MediaImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final double placeholderHeight;
  final BoxFit fit;

  const MediaImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.placeholderHeight = 200,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('/')) {
      return Image.file(
        File(imageUrl),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            Icons.error,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    }

    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
            ShimmerLoading(height: placeholderHeight),
        errorWidget: (context, url, error) => Center(
          child: Icon(
            Icons.error,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          Icons.image,
          color: Theme.of(context).disabledColor,
        ),
      ),
    );
  }
}

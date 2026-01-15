import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A widget for displaying cached GIFs with loading and error states.
///
/// This widget uses CachedNetworkImage to efficiently load and cache GIFs
/// from network URLs. It provides customizable placeholders for loading
/// and error states.
class CachedGif extends StatelessWidget {
  /// The URL of the GIF to display.
  final String url;

  /// How the GIF should be inscribed into the space allocated.
  final BoxFit? fit;

  /// Widget to display while the GIF is loading.
  final Widget Function(BuildContext, String)? placeholder;

  /// Widget to display if there's an error loading the GIF.
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const CachedGif({
    Key? key,
    required this.url,
    this.fit,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );
  }
}

